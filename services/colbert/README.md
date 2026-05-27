# ColBERT sidecar

A FastAPI service that runs the ColBERT model out-of-process from Rails. The
Ruby `ColbertClient` talks to it over localhost HTTP.

## Install

```bash
cd services/colbert
python3 -m venv .venv                     # python 3.11+ works; 3.12 verified
source .venv/bin/activate

# CPU-only torch is much smaller (~200 MB vs ~800 MB CUDA wheel) and is
# what we want on the Hetzner box anyway:
pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt
```

First run will download `answerdotai/answerai-colbert-small-v1` from Hugging
Face (~130 MB safetensors). Cache lives at `$HF_HOME` (default `~/.cache/huggingface`).

## Important: projection layer

The `answerai-colbert-*` checkpoints contain a `linear.weight` projection (96,384
for `-small-v1`) sitting outside the BERT backbone. `transformers.AutoModel`
loads the bert.* weights but silently drops the projection — leaving you with
raw 384-dim hidden states instead of the 96-dim ColBERT embeddings the schema
expects. `main.py` loads the projection from the same checkpoint and applies
it after the BERT forward pass. If you swap to a different checkpoint, verify
its hidden shape matches the `chunks.dense_vec vector(N)` migration.

## Run

```bash
uvicorn services.colbert.main:app --host 127.0.0.1 --port 7400 --workers 1
```

Production uses systemd — see `deploy/systemd/13f-colbert.service`.

## Env vars

| Var | Default | Description |
|---|---|---|
| `COLBERT_MODEL` | `answerdotai/answerai-colbert-small-v1` | HF model id |
| `COLBERT_MAX_DOC_TOKENS` | `300` | Truncation for chunk encoding |
| `COLBERT_MAX_QUERY_TOKENS` | `32` | Truncation for queries |
| `HF_HOME` | `~/.cache/huggingface` | Model cache dir |

## Smoke test

```bash
curl 127.0.0.1:7400/health

curl -X POST 127.0.0.1:7400/embed_chunk \
  -H 'Content-Type: application/json' \
  -d '{"text":"Apple beat EPS in Q3 2025."}'

curl -X POST 127.0.0.1:7400/encode_query \
  -H 'Content-Type: application/json' \
  -d '{"text":"Apple earnings"}'
```

## Resource usage

| Phase | RAM | CPU |
|---|---|---|
| Idle | ~250 MB | 0% |
| /embed_chunk (200 tokens) | +50 MB | ~80% one core |
| /score (200 candidates) | +30 MB | ~80% one core |

Fits inside Hetzner CCX23 alongside Rails + Postgres comfortably.

## Why a sidecar instead of in-process

1. **Memory isolation** — Ruby on Rails + a 500 MB ML model in the same process
   means GC pauses get ugly. Keep them apart.
2. **Restart independence** — model updates ship via `systemctl restart 13f-colbert`
   without bouncing the API.
3. **Language fit** — `transformers` and the ColBERT ecosystem are Python-native;
   bridging to Ruby would mean PyCall or RPC anyway.

## Alternatives we evaluated and rejected

- **In-process via PyCall** — fragile, conflicts with Rails autoloader, no isolation.
- **ONNX runtime inside Ruby** — possible but the ColBERT model needs custom pooling
  that isn't well-supported in onnxruntime-ruby yet (as of late 2025).
- **External vector DB (Qdrant, Weaviate)** — adds a service to the stack; user
  wants Postgres only.
