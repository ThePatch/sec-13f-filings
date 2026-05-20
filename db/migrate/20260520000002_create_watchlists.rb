# db/migrate/20260520000002_create_watchlists.rb
class CreateWatchlists < ActiveRecord::Migration[7.1]
  def change
    create_table :watchlists do |t|
      t.string :session_id, null: false      # cookie session id; switch to user_id when auth lands
      t.string :name,        null: false
      t.string :filer_ciks,  array: true, null: false, default: []
      t.string :cusips,      array: true, null: false, default: []
      t.boolean :notifications, null: false, default: false
      t.timestamps
    end

    add_index :watchlists, :session_id
  end
end
