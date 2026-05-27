class CreateDocuments < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE documents (
        id            BIGSERIAL PRIMARY KEY,
        company_id    BIGINT REFERENCES companies(id) ON DELETE CASCADE,
        doc_type      TEXT NOT NULL,
        source        TEXT NOT NULL,
        source_ref    TEXT,
        title         TEXT,
        authors       TEXT[] NOT NULL DEFAULT '{}',
        published_at  TIMESTAMPTZ NOT NULL,
        fiscal_period TEXT,
        raw_text      TEXT,
        raw_url       TEXT,
        language      VARCHAR(8) NOT NULL DEFAULT 'en',
        word_count    INT,
        hash          TEXT NOT NULL,
        metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
        ingested_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        processed_at  TIMESTAMPTZ,

        UNIQUE (source, source_ref)
      );

      CREATE INDEX documents_company_published ON documents (company_id, published_at DESC);
      CREATE INDEX documents_doc_type_published ON documents (doc_type, published_at DESC);
      CREATE INDEX documents_hash ON documents (hash);
      CREATE INDEX documents_unprocessed ON documents (ingested_at) WHERE processed_at IS NULL;

      COMMENT ON TABLE documents IS 'Raw source documents. One per news article, earnings call, SEC filing. Deduped by (source, source_ref) and by hash.';
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS documents CASCADE"
  end
end
