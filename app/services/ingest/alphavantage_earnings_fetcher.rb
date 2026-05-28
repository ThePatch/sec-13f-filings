require "digest"

module Ingest
  class AlphavantageEarningsFetcher < BaseFetcher
    DAILY_LIMIT = 25
    BASE_URL    = "https://www.alphavantage.co/query".freeze

    def fetch_for_watchlist(tickers)
      created = []
      Array(tickers).each do |ticker|
        respect_rate_limit("alphavantage", requests_per_minute: 5)
        track_quota("alphavantage", used: 1, daily_limit: DAILY_LIMIT)

        company = Company.find_by(ticker: ticker.to_s.upcase)
        next unless company

        latest = latest_transcript_for(ticker)
        next unless latest

        doc = ingest_transcript(company, latest)
        created << doc.id if doc&.respond_to?(:id)
      end
      created
    rescue QuotaExceededError
      # Daily quota hit — stop politely; resume tomorrow.
      created
    end

    private

    def latest_transcript_for(ticker)
      with_retry do
        response = HTTParty.get(BASE_URL, query: {
          function: "EARNINGS_CALL_TRANSCRIPT",
          symbol:   ticker.to_s.upcase,
          apikey:   api_key,
          quarter:  "latest",
        }, timeout: 30)
        return nil unless response.success?
        body = response.parsed_response
        return nil unless body.is_a?(Hash) && body["transcript"].is_a?(Array) && body["transcript"].any?
        {
          quarter:   body["quarter"],
          symbol:    body["symbol"],
          transcript: body["transcript"],
        }
      end
    end

    def ingest_transcript(company, payload)
      source_ref = "#{company.ticker}/#{payload[:quarter]}"
      dedup_by_source_ref(source: "alphavantage", ref: source_ref) do
        text = format_transcript(payload[:transcript])
        Document.create!(
          source:        "alphavantage",
          source_ref:    source_ref,
          company_id:    company.id,
          doc_type:      "earnings_call",
          title:         "#{company.name} earnings call #{payload[:quarter]}",
          authors:       [],
          published_at:  Time.current,
          fiscal_period: payload[:quarter],
          raw_text:      text,
          word_count:    text.split.size,
          content_hash:  Digest::SHA256.hexdigest(text),
          metadata:      { ticker: payload[:symbol], quarter: payload[:quarter] },
        )
      end
    end

    def format_transcript(turns)
      turns.map do |t|
        speaker = t["speaker"].to_s
        title   = t["title"].to_s.empty? ? "" : " — #{t["title"]}"
        content = t["content"].to_s
        "[#{speaker}#{title}]\n#{content}"
      end.join("\n\n")
    end

    def api_key
      ENV.fetch("ALPHAVANTAGE_API_KEY") { raise FetcherError, "ALPHAVANTAGE_API_KEY not set" }
    end
  end
end
