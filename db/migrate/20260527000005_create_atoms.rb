class CreateAtoms < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE atoms (
        id                  BIGSERIAL PRIMARY KEY,
        company_id          BIGINT REFERENCES companies(id) ON DELETE SET NULL,
        filer_cik           VARCHAR(10),
        chunk_id            BIGINT REFERENCES chunks(id) ON DELETE SET NULL,
        document_id         BIGINT REFERENCES documents(id) ON DELETE SET NULL,

        profile             atom_profile NOT NULL DEFAULT 'standard',
        stream              atom_stream  NOT NULL DEFAULT 'semantic',
        state               atom_state   NOT NULL DEFAULT 'active',

        content             TEXT NOT NULL,
        content_hash        TEXT NOT NULL,
        token_count         INT NOT NULL,
        source_quote        TEXT,

        access_count        INT NOT NULL DEFAULT 0,
        last_accessed_at    TIMESTAMPTZ,
        stability           REAL NOT NULL DEFAULT 1.0,
        retrievability      REAL NOT NULL DEFAULT 1.0,

        arousal             REAL NOT NULL DEFAULT 0.0,
        valence             REAL NOT NULL DEFAULT 0.0,
        encoding_confidence REAL NOT NULL DEFAULT 0.7,

        embedding           vector(384),

        topics              TEXT[] NOT NULL DEFAULT '{}',
        metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,

        is_pinned           BOOLEAN NOT NULL DEFAULT FALSE,

        created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

        UNIQUE (content_hash, company_id)
      );

      CREATE INDEX atoms_company_state ON atoms (company_id, state, retrievability DESC);
      CREATE INDEX atoms_filer_state ON atoms (filer_cik, state) WHERE filer_cik IS NOT NULL;
      CREATE INDEX atoms_embedding_hnsw ON atoms USING hnsw (embedding vector_cosine_ops);
      CREATE INDEX atoms_topics_gin ON atoms USING gin (topics);
      CREATE INDEX atoms_last_accessed ON atoms (last_accessed_at);
      CREATE INDEX atoms_active_recent ON atoms (last_accessed_at DESC) WHERE state = 'active';

      COMMENT ON TABLE atoms IS 'MSAM-style memory atoms. Compressed claims extracted from chunks. Scored by ACT-R activation. Decay over time. Never deleted.';
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS atoms CASCADE"
  end
end
