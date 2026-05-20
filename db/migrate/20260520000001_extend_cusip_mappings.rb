# db/migrate/20260520000001_extend_cusip_mappings.rb
class ExtendCusipMappings < ActiveRecord::Migration[7.1]
  def change
    change_table :cusip_symbol_mappings do |t|
      t.string  :source,     null: false, default: 'manual'   # seed-yf | sec-ticker | openfigi | manual | unresolved
      t.float   :confidence, null: false, default: 1.0        # 0..1
      t.string  :cik                                          # null if not a SEC filer (e.g. ETFs)
      t.datetime :verified_at
    end

    add_index :cusip_symbol_mappings, :source
    add_index :cusip_symbol_mappings, :cik
    add_index :cusip_symbol_mappings, :verified_at
  end
end
