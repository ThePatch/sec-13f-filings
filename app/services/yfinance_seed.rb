# app/services/yfinance_seed.rb
#
# Seed/refresh the cusip_symbol_mappings table from yfinance via a Python
# sidecar (bin/yfinance_seed.py). Reads the script's CSV stdout and upserts.
# Manual entries (source: 'manual') are NEVER overwritten.

require 'csv'
require 'shellwords'

class YfinanceSeed
  SCRIPT_REL_PATH = ['bin', 'yfinance_seed.py'].freeze

  def call
    script_path = Rails.root.join(*SCRIPT_REL_PATH)
    raise "yfinance_seed.py missing at #{script_path}" unless File.exist?(script_path)

    csv_data = `python3 #{Shellwords.escape(script_path.to_s)}`
    raise "yfinance_seed.py failed (exit #{$?.exitstatus})" unless $?.success?

    added = 0
    updated = 0
    preserved_manual = 0

    CSV.parse(csv_data, headers: true).each do |row|
      cusip  = row['cusip']
      symbol = row['symbol']
      next unless cusip && symbol

      existing = CusipSymbolMapping.find_by(cusip: cusip)
      if existing && existing.source == 'manual'
        preserved_manual += 1
        next
      end

      attrs = {
        cusip: cusip,
        symbol: symbol,
        name: row['name'],
        exchange: row['exchange'],
        cik: row['cik'],
        source: 'seed-yf',
        confidence: 1.0,
        verified_at: Time.current,
      }

      if existing
        existing.update(attrs.except(:cusip))
        updated += 1
      else
        CusipSymbolMapping.create!(attrs)
        added += 1
      end
    end

    { added: added, updated: updated, preserved_manual: preserved_manual }
  end
end
