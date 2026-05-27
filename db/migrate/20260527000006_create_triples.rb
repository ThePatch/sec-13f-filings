class CreateTriples < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE triples (
        id             BIGSERIAL PRIMARY KEY,
        subject        TEXT NOT NULL,
        predicate      TEXT NOT NULL,
        object         TEXT NOT NULL,
        confidence     REAL NOT NULL DEFAULT 0.7,
        valid_from     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        valid_until    TIMESTAMPTZ,
        source_atom_id BIGINT REFERENCES atoms(id) ON DELETE SET NULL,
        metadata       JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

        UNIQUE (subject, predicate, object, valid_from)
      );

      CREATE INDEX triples_subject ON triples (subject);
      CREATE INDEX triples_subject_predicate ON triples (subject, predicate);
      CREATE INDEX triples_valid_window ON triples (valid_from, valid_until);
      CREATE INDEX triples_currently_valid ON triples (subject, predicate) WHERE valid_until IS NULL;

      COMMENT ON TABLE triples IS 'Knowledge graph. Carries temporal metadata so historical state can be reconstructed. Updating a fact auto-closes the old triple.';
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS triples CASCADE"
  end
end
