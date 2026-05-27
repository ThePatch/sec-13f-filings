# app/services/sec_ticker_sync.rb
#
# Pulls https://www.sec.gov/files/company_tickers.json (free, no key) and
# upserts CIK <-> ticker mappings into cusip_symbol_mappings. This source does
# NOT provide CUSIPs; it primarily backfills CIK/symbol/name on rows that
# already have a CUSIP from another source. Use OpenFIGI to obtain CUSIPs.
#
# The SEC requires a descriptive User-Agent on every request. The fork
# already sets one in lib/sec_user_agent.rb for crawlers, but services run
# independently, so we accept either SEC_USER_AGENT env var or fall back to
# the project default.

require 'httparty'

class SecTickerSync
  URL = 'https://www.sec.gov/files/company_tickers.json'.freeze
  DEFAULT_USER_AGENT = 'F13 Explorer beeisrael@gmail.com'.freeze

  def call
    user_agent = ENV['SEC_USER_AGENT'] || DEFAULT_USER_AGENT

    response = HTTParty.get(URL, headers: {
      'User-Agent' => user_agent,
      'Accept'     => 'application/json',
    })
    raise "SEC ticker fetch failed: #{response.code}" unless response.success?

    data = response.parsed_response   # { "0" => {cik_str, ticker, title}, ... }

    added = 0
    updated = 0

    data.each_value do |row|
      cik    = row['cik_str'].to_s.rjust(10, '0')
      ticker = row['ticker']
      title  = row['title']

      mappings = CusipSymbolMapping.where(cik: cik).or(CusipSymbolMapping.where(symbol: ticker))
      next unless mappings.exists?

      mappings.each do |m|
        next if m.source == 'manual'   # never overwrite manual entries

        changes = { name: title }
        changes[:cik]    = cik    if m.cik.blank?
        changes[:symbol] = ticker if m.symbol.blank?
        changes[:source] = 'sec-ticker' if m.source == 'unresolved'
        changes[:verified_at] = Time.current
        m.update(changes)
        updated += 1
      end
    end

    {
      added: added,
      updated: updated,
      total: data.size,
    }
  end
end
