# app/services/open_figi_client.rb
#
# Thin wrapper around https://api.openfigi.com/v3/mapping
# Free tier: 25 requests/min without key, 1000 requests/min with key.
# Each request is a batch of up to 100 IDs.
#
# Rate limits enforced via sleep_between:
#   - Without API key: 6.0s between batches (~10 req/min, safely under 25)
#   - With API key:    0.5s between batches (~120 req/min, under 1000)

require 'httparty'

class OpenFigiClient
  include HTTParty
  base_uri 'https://api.openfigi.com'
  default_timeout 30

  def initialize(api_key: ENV['OPENFIGI_KEY'] || ENV['OPENFIGI_API_KEY'])
    @api_key = api_key
    @headers = { 'Content-Type' => 'application/json' }
    @headers['X-OPENFIGI-APIKEY'] = api_key if api_key
    @sleep_between = api_key ? 0.5 : 6.0
  end

  # Resolve a list of CUSIPs to ticker + name + exchange.
  # Returns Array<Hash> of resolved entries; unresolved CUSIPs are skipped.
  def resolve(cusips)
    return [] if cusips.nil? || cusips.empty?

    resolved = []
    cusips.each_slice(100) do |batch|
      payload = batch.map { |c| { idType: 'ID_CUSIP', idValue: c } }
      response = self.class.post('/v3/mapping', body: payload.to_json, headers: @headers)
      raise "OpenFIGI request failed: #{response.code}" unless response.success?

      batch.each_with_index do |cusip, i|
        result = response.parsed_response[i]
        next unless result&.dig('data')&.first
        first = result['data'].first
        resolved << {
          cusip: cusip,
          symbol: first['ticker'],
          name: first['name'],
          exchange: first['exchCode'],
          confidence: 0.97,
          source: 'openfigi',
        }
      end

      sleep @sleep_between
    end

    resolved
  end
end

# app/services/open_figi_resolver.rb
# Runs OpenFigiClient against all unresolved rows in cusip_symbol_mappings.
class OpenFigiResolver
  def resolve_unresolved!
    unresolved = CusipSymbolMapping.where(source: 'unresolved').pluck(:cusip)
    return { resolved: 0, still_unresolved: 0, remaining: 0 } if unresolved.empty?

    client = OpenFigiClient.new
    results = client.resolve(unresolved)

    results.each do |r|
      CusipSymbolMapping.where(cusip: r[:cusip]).update_all(
        symbol: r[:symbol],
        name: r[:name],
        exchange: r[:exchange],
        confidence: r[:confidence],
        source: r[:source],
        verified_at: Time.current,
        updated_at: Time.current,
      )
    end

    {
      resolved: results.length,
      still_unresolved: unresolved.length - results.length,
      remaining: CusipSymbolMapping.where(source: 'unresolved').count,
    }
  end
end
