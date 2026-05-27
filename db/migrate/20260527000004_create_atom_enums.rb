class CreateAtomEnums < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DO $$ BEGIN
        CREATE TYPE atom_profile AS ENUM ('lightweight', 'standard', 'full');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE atom_stream AS ENUM ('semantic', 'episodic', 'procedural', 'working');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;

      DO $$ BEGIN
        CREATE TYPE atom_state AS ENUM ('active', 'fading', 'dormant', 'tombstone');
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    SQL
  end

  def down
    execute <<~SQL
      DROP TYPE IF EXISTS atom_state;
      DROP TYPE IF EXISTS atom_stream;
      DROP TYPE IF EXISTS atom_profile;
    SQL
  end
end
