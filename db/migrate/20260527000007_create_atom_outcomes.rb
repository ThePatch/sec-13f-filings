class CreateAtomOutcomes < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE atom_outcomes (
        id          BIGSERIAL PRIMARY KEY,
        atom_id     BIGINT NOT NULL REFERENCES atoms(id) ON DELETE CASCADE,
        session_id  TEXT NOT NULL,
        signal      REAL NOT NULL,
        reason      TEXT,
        metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE INDEX atom_outcomes_atom ON atom_outcomes (atom_id, created_at DESC);
      CREATE INDEX atom_outcomes_session ON atom_outcomes (session_id, created_at DESC);
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS atom_outcomes CASCADE"
  end
end
