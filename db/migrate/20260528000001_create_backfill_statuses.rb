class CreateBackfillStatuses < ActiveRecord::Migration[6.1]
  def change
    create_table :backfill_statuses do |t|
      t.references :company, null: false, foreign_key: true, index: { unique: true }
      t.string :state, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :document_count, null: false, default: 0
      t.jsonb :breakdown, null: false, default: {}
      t.text :last_error
      t.timestamps
    end
  end
end
