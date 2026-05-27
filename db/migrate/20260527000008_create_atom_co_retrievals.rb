class CreateAtomCoRetrievals < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE atom_co_retrievals (
        atom_a   BIGINT NOT NULL REFERENCES atoms(id) ON DELETE CASCADE,
        atom_b   BIGINT NOT NULL REFERENCES atoms(id) ON DELETE CASCADE,
        count    INT NOT NULL DEFAULT 1,
        last_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

        PRIMARY KEY (atom_a, atom_b),
        CHECK (atom_a < atom_b)
      );

      CREATE INDEX atom_co_retrievals_a ON atom_co_retrievals (atom_a, count DESC);
      CREATE INDEX atom_co_retrievals_b ON atom_co_retrievals (atom_b, count DESC);
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS atom_co_retrievals CASCADE"
  end
end
