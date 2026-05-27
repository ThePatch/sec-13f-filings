class CreateChunks < ActiveRecord::Migration[6.1]
  # NOTE: text_tsv is a Postgres GENERATED column. Rails 6.1 has no DSL for it
  # (t.virtual lands in Rails 7.1), so we use raw SQL here.
  def up
    execute <<~SQL
      CREATE TABLE chunks (
        id             BIGSERIAL PRIMARY KEY,
        document_id    BIGINT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        ordinal        INT NOT NULL,
        text           TEXT NOT NULL,
        token_count    INT NOT NULL,
        start_char     INT NOT NULL,
        end_char       INT NOT NULL,
        speaker        TEXT,
        section        TEXT,

        dense_vec      vector(96),

        colbert_blob   BYTEA NOT NULL,
        colbert_dim    INT NOT NULL DEFAULT 96,
        colbert_tokens INT NOT NULL,

        text_tsv       tsvector GENERATED ALWAYS AS (to_tsvector('english', text)) STORED,

        created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

        UNIQUE (document_id, ordinal)
      );

      CREATE INDEX chunks_document ON chunks (document_id, ordinal);
      CREATE INDEX chunks_dense_vec_hnsw ON chunks USING hnsw (dense_vec vector_cosine_ops);
      CREATE INDEX chunks_text_tsv ON chunks USING gin (text_tsv);

      COMMENT ON TABLE chunks IS 'ColBERT-indexed text spans. dense_vec for first-pass HNSW; colbert_blob for late-interaction re-rank in the Python sidecar.';
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS chunks CASCADE"
  end
end
