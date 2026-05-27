class CreateCompanies < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE companies (
        id          BIGSERIAL PRIMARY KEY,
        cusip       VARCHAR(9) NOT NULL UNIQUE,
        ticker      VARCHAR(10),
        cik         VARCHAR(10),
        name        TEXT NOT NULL,
        sector      TEXT,
        industry    TEXT,
        exchange    VARCHAR(20),
        ir_url      TEXT,
        rss_url     TEXT,
        metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE INDEX companies_ticker_idx ON companies (ticker);
      CREATE INDEX companies_cik_idx ON companies (cik);
      CREATE INDEX companies_name_trgm ON companies USING gin (name gin_trgm_ops);

      COMMENT ON TABLE companies IS 'Canonical company record. One row per CUSIP. Populated from cusip_symbol_mappings during initial seed.';
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS companies CASCADE"
  end
end
