require "digest"

module Ingest
  class FinnhubNewsFetcher < BaseFetcher
    BASE_URL  = "https://finnhub.io/api/v1/company-news".freeze
    POLL_RPM  = 60   # free-tier ceiling

    # tickers: Array<String>; lookback: 7 days by default per the plan.
    def fetch_for_tickers(tickers, lookback: 7.days)
      created = []
      Array(tickers).each do |ticker|
        respect_rate_limit("finnhub", requests_per_minute: POLL_RPM)
        company = Company.find_by(ticker: ticker.to_s.upcase)
        next unless company

        articles = fetch_articles(ticker, from: lookback.ago.to_date, to: Date.today)
        articles.each do |a|
          doc = ingest_article(company, a)
          created << doc.id if doc&.respond_to?(:id)
        end
      end
      created
    end

    private

    def fetch_articles(ticker, from:, to:)
      with_retry do
        response = HTTParty.get(BASE_URL, query: {
          symbol: ticker.to_s.upcase,
          from:   from.iso8601,
          to:     to.iso8601,
          token:  api_key,
        }, timeout: 30)
        return [] unless response.success?
        Array(response.parsed_response)
      end
    rescue FetcherError
      []
    end

    def ingest_article(company, article)
      source_ref = article["id"]&.to_s || article["url"].to_s
      return nil if source_ref.empty?

      dedup_by_source_ref(source: "finnhub", ref: source_ref) do
        body = [article["headline"], article["summary"]].compact.join("\n\n")
        next nil if body.strip.empty?

        Document.create!(
          source:        "finnhub",
          source_ref:    source_ref,
          company_id:    company.id,
          doc_type:      "news",
          title:         article["headline"],
          authors:       Array(article["source"]).compact,
          published_at:  article["datetime"] ? Time.at(article["datetime"]) : Time.current,
          raw_url:       article["url"],
          raw_text:      body,
          word_count:    body.split.size,
          content_hash:  Digest::SHA256.hexdigest(body),
          metadata:      { category: article["category"], related: article["related"], image: article["image"] },
        )
      end
    end

    def api_key
      ENV.fetch("FINNHUB_API_KEY") { raise FetcherError, "FINNHUB_API_KEY not set" }
    end
  end
end
