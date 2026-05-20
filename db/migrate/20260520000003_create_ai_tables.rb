# db/migrate/20260520000003_create_ai_tables.rb
class CreateAiTables < ActiveRecord::Migration[7.1]
  def change
    # Provider config — per-session API key + default model.
    # When real auth lands, swap session_id for user_id.
    create_table :ai_provider_configs do |t|
      t.string :session_id, null: false
      t.string :provider,   null: false                   # claude | openai | groq | openrouter | nim | ollama
      t.text   :api_key_ciphertext                        # ActiveRecord encryption
      t.string :default_model
      t.string :endpoint                                  # only for ollama / openrouter custom
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :ai_provider_configs, [:session_id, :provider], unique: true

    # Conversation log (for the chat history sidebar).
    create_table :ai_conversations do |t|
      t.string :session_id, null: false
      t.string :title
      t.jsonb  :messages, null: false, default: []
      t.jsonb  :context,  null: false, default: []
      t.timestamps
    end
    add_index :ai_conversations, [:session_id, :updated_at]

    # Pre-generated insights from the background job.
    create_table :ai_insights do |t|
      t.string :kind, null: false                         # rotation | new | crowding | anomaly | exit
      t.string :filer_cik
      t.string :filer_name
      t.string :cusip
      t.text   :headline, null: false
      t.text   :body,     null: false
      t.string :tags, array: true, null: false, default: []
      t.float  :confidence, null: false, default: 0.5
      t.string :model, null: false
      t.jsonb  :payload, null: false, default: {}
      t.timestamps
    end
    add_index :ai_insights, [:kind, :created_at]
    add_index :ai_insights, [:filer_cik, :created_at]
    add_index :ai_insights, [:cusip, :created_at]
  end
end
