class CreateConversations < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE TABLE conversations (
        id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        session_id  TEXT NOT NULL,
        title       TEXT,
        shared      BOOLEAN NOT NULL DEFAULT FALSE,
        share_slug  TEXT UNIQUE,
        context     JSONB NOT NULL DEFAULT '[]'::jsonb,
        messages    JSONB NOT NULL DEFAULT '[]'::jsonb,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE INDEX conversations_session ON conversations (session_id, updated_at DESC);
      CREATE INDEX conversations_share ON conversations (share_slug) WHERE share_slug IS NOT NULL;
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS conversations CASCADE"
  end
end
