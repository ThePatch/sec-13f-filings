# MSAM (cognitive memory layer) tuning constants. All knobs live here so they
# can be moved without editing service classes. Documented in
# handoff/v2/02_ARCHITECTURE.md.
#
# Override per-env via ENV vars when you want to tune without redeploy.

MSAM_CONFIG = {
  # ─── Retrieval shape ──────────────────────────────────────────────
  default_top_k:    5,    # final atoms/chunks returned to the caller
  pgvector_top_k:   200,  # candidates pulled from dense first-pass
  colbert_top_k:    8,    # after ColBERT MaxSim re-rank

  # ─── Confidence gating (per query-token MaxSim score) ─────────────
  # 0.62/0.45/0.30 are tuned on Anthropic's financial-text fixture. Increase
  # to be stricter (more "I don't have that"), decrease to surface more.
  tier_thresholds: {
    high:   0.62,
    medium: 0.45,
    low:    0.30,
  },

  # ─── ACT-R activation formula ─────────────────────────────────────
  # activation = (base + sim*sim_w + recency*rec_w + outcome*out_w) * stability
  activation: {
    sim_weight:        2.0,
    recency_weight:    0.5,
    outcome_weight:    0.3,
    recency_half_life_hours: 168.0,    # 1 week
    min_outcomes_for_signal: 3,         # below this, outcome score = 0 (noise floor)
  },

  # ─── Atom lifecycle (decay job; T-524) ────────────────────────────
  decay: {
    active_to_fading_r:   0.30,    # retrievability threshold
    fading_to_dormant_r:  0.10,
    compact_on_state:     :fading,  # full → standard → lightweight
  },

  # ─── Extraction model defaults (T-520, T-521) ─────────────────────
  extraction_model:        ENV.fetch("MSAM_EXTRACTION_MODEL", "claude-haiku-4-5"),
  atom_embedding_provider: ENV.fetch("MSAM_ATOM_EMBEDDING_PROVIDER", "nim"),
  atom_embedding_model:    ENV.fetch("MSAM_ATOM_EMBEDDING_MODEL", "nvidia/nv-embedqa-e5-v5"),
}.freeze
