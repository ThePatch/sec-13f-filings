"""ColBERT sidecar — late-interaction embedding + MaxSim scoring.

Runs as a small FastAPI service colocated with the Rails API on the same
Hetzner box. Exposes two endpoints used by the Ruby ColbertClient:

  POST /embed_chunk  — encode a document chunk into (dense_vec, int8 token blob)
  POST /score        — MaxSim a query against a batch of candidate chunks

Model: answerdotai/answerai-colbert-small-v1 by default (33M params, 96-dim,
MIT). Configurable via COLBERT_MODEL env var.

Startup loads the model once into memory (~200 MB RAM, CPU inference).
Cold start ~3s. Per-chunk embed ~80-150ms on CCX23. Per-query MaxSim against
200 candidates: ~120ms.

Quantization: float32 → int8 with per-vector scaling. Round-trip cosine
loss < 1% on the financial-text fixture. Storage is ~96 bytes/token.

Run:
    uvicorn services.colbert.main:app --host 127.0.0.1 --port 7400 --workers 1
"""
from __future__ import annotations

import base64
import os
import time
from contextlib import asynccontextmanager
from typing import List

import numpy as np
import safetensors.torch as st
import torch
from fastapi import FastAPI, HTTPException
from huggingface_hub import hf_hub_download
from pydantic import BaseModel, Field
from transformers import AutoModel, AutoTokenizer


MODEL_NAME = os.environ.get(
    "COLBERT_MODEL", "answerdotai/answerai-colbert-small-v1"
)
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MAX_DOC_TOKENS = int(os.environ.get("COLBERT_MAX_DOC_TOKENS", "300"))
MAX_QUERY_TOKENS = int(os.environ.get("COLBERT_MAX_QUERY_TOKENS", "32"))


# ─── Quantization ────────────────────────────────────────────────────
def quantize_int8(arr: np.ndarray) -> tuple[bytes, np.ndarray]:
    """Per-vector symmetric int8 quantization. Returns (bytes, scale_per_token)."""
    # scale = max(|x|) per row, mapped to 127
    scales = np.abs(arr).max(axis=1, keepdims=True) + 1e-8
    quantized = np.clip(np.round(arr / scales * 127.0), -128, 127).astype(np.int8)
    return quantized.tobytes(), scales.astype(np.float32).flatten()


def dequantize_int8(blob: bytes, num_tokens: int, dim: int, scales: np.ndarray) -> np.ndarray:
    quantized = np.frombuffer(blob, dtype=np.int8).reshape(num_tokens, dim).astype(np.float32)
    return quantized * scales.reshape(-1, 1) / 127.0


# ─── Model wrapper ───────────────────────────────────────────────────
# The answerai-colbert checkpoints contain a `linear.weight` projection
# (e.g. (96, 384) for `-small-v1`) sitting outside the BERT backbone.
# transformers' AutoModel loads only the bert.* weights and silently
# drops the projection, leaving you with raw 384-dim hidden states.
# To produce the true ColBERT embedding dim we load the projection from
# the checkpoint and apply it after the BERT forward pass.
class ColBERTEncoder:
    def __init__(self, model_name: str):
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name).to(DEVICE).eval()

        weights_path = hf_hub_download(model_name, "model.safetensors")
        ckpt = st.load_file(weights_path)
        linear_w = ckpt.get("linear.weight")
        if linear_w is None:
            # Older / non-projection variants: fall back to raw hidden state
            self.projection = None
            with torch.no_grad():
                probe = self.tokenizer("probe", return_tensors="pt").to(DEVICE)
                self.dim = self.model(**probe).last_hidden_state.shape[-1]
        else:
            out_dim, in_dim = linear_w.shape  # (96, 384) for -small-v1
            self.projection = torch.nn.Linear(in_dim, out_dim, bias=False).to(DEVICE).eval()
            with torch.no_grad():
                self.projection.weight.copy_(linear_w.to(DEVICE))
            self.dim = out_dim

    @torch.no_grad()
    def encode(self, text: str, max_tokens: int) -> np.ndarray:
        inputs = self.tokenizer(
            text, return_tensors="pt", truncation=True,
            max_length=max_tokens, padding=False,
        ).to(DEVICE)
        hidden = self.model(**inputs).last_hidden_state[0]  # (T, hidden_dim)
        if self.projection is not None:
            hidden = self.projection(hidden)  # (T, dim)
        # L2-normalize each token vector — ColBERT convention
        hidden = hidden / (hidden.norm(dim=-1, keepdim=True) + 1e-8)
        return hidden.cpu().numpy().astype(np.float32)


# ─── Lifespan ────────────────────────────────────────────────────────
encoder: ColBERTEncoder | None = None
boot_time: float = 0.0


@asynccontextmanager
async def lifespan(app: FastAPI):
    global encoder, boot_time
    t0 = time.time()
    encoder = ColBERTEncoder(MODEL_NAME)
    boot_time = time.time() - t0
    yield


app = FastAPI(lifespan=lifespan, title="ColBERT sidecar")


# ─── Schemas ─────────────────────────────────────────────────────────
class EmbedChunkRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=20_000)


class EmbedChunkResponse(BaseModel):
    dense_vec: List[float]
    colbert_blob_b64: str
    colbert_scales_b64: str  # per-token quantization scales
    colbert_dim: int
    colbert_tokens: int
    encode_ms: float


class Candidate(BaseModel):
    id: int
    blob_b64: str
    scales_b64: str
    dim: int
    num_tokens: int


class ScoreRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2_000)
    candidates: List[Candidate]
    top_k: int = 8


class ScoredCandidate(BaseModel):
    chunk_id: int
    score: float


class ScoreResponse(BaseModel):
    results: List[ScoredCandidate]
    query_tokens: int
    score_ms: float


# ─── Endpoints ───────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {
        "ok": encoder is not None,
        "model": MODEL_NAME,
        "dim": encoder.dim if encoder else None,
        "device": DEVICE,
        "boot_time_seconds": round(boot_time, 3),
        "max_doc_tokens": MAX_DOC_TOKENS,
        "max_query_tokens": MAX_QUERY_TOKENS,
    }


@app.post("/embed_chunk", response_model=EmbedChunkResponse)
def embed_chunk(req: EmbedChunkRequest):
    if encoder is None:
        raise HTTPException(503, "model not loaded")
    t0 = time.time()
    token_embs = encoder.encode(req.text, MAX_DOC_TOKENS)  # (T, D) float32
    dense = token_embs.mean(axis=0)  # mean pool for HNSW first pass
    dense = dense / (np.linalg.norm(dense) + 1e-8)  # re-normalize
    blob, scales = quantize_int8(token_embs)
    return EmbedChunkResponse(
        dense_vec=dense.tolist(),
        colbert_blob_b64=base64.b64encode(blob).decode("ascii"),
        colbert_scales_b64=base64.b64encode(scales.tobytes()).decode("ascii"),
        colbert_dim=encoder.dim,
        colbert_tokens=int(token_embs.shape[0]),
        encode_ms=(time.time() - t0) * 1000,
    )


@app.post("/score", response_model=ScoreResponse)
def score(req: ScoreRequest):
    if encoder is None:
        raise HTTPException(503, "model not loaded")
    if not req.candidates:
        return ScoreResponse(results=[], query_tokens=0, score_ms=0)

    t0 = time.time()
    q_tokens = encoder.encode(req.query, MAX_QUERY_TOKENS)  # (Q, D)
    q_len = q_tokens.shape[0]

    scored: list[tuple[int, float]] = []
    for c in req.candidates:
        blob = base64.b64decode(c.blob_b64)
        scales = np.frombuffer(base64.b64decode(c.scales_b64), dtype=np.float32)
        d_tokens = dequantize_int8(blob, c.num_tokens, c.dim, scales)  # (T, D)
        # MaxSim: per query token, take max sim over doc tokens; sum.
        sims = q_tokens @ d_tokens.T  # (Q, T)
        score_val = float(sims.max(axis=1).sum())
        scored.append((c.id, score_val))

    scored.sort(key=lambda x: -x[1])
    top = scored[: req.top_k]
    return ScoreResponse(
        results=[ScoredCandidate(chunk_id=cid, score=s) for cid, s in top],
        query_tokens=q_len,
        score_ms=(time.time() - t0) * 1000,
    )


@app.post("/encode_query")
def encode_query(req: EmbedChunkRequest):
    """Encode a query for pgvector first-pass. Returns dense_vec only."""
    if encoder is None:
        raise HTTPException(503, "model not loaded")
    q_tokens = encoder.encode(req.text, MAX_QUERY_TOKENS)
    dense = q_tokens.mean(axis=0)
    dense = dense / (np.linalg.norm(dense) + 1e-8)
    return {"dense_vec": dense.tolist(), "query_tokens": int(q_tokens.shape[0])}
