require "digest"

module Ingest
  class NewsApiFetcher < BaseFetcher
    DAILY_LIMIT = 100
    BASE_URL    = "https://newsapi.org/v2/everything".freeze

    # NewsAPI's free tier prohibits caching beyond 24h. Documents are inserted
    # with `raw_text` but the daily purge job (Ingest::PurgeNewsApiRawTextJob)
    # nulls raw_text and deletes chunks after 24h. Atoms derived from the doc
    # survive — they're the compressed extract.
    def fetch_for_query(query, page_size: 50)
      track_quota("newsapi", used: 1, daily_limit: DAILY_LIMIT)
      results = call_newsapi(query, page_size)
      created = []
      results.each do |r|
        doc = ingest_record(query, r)
        created << doc.id if doc&.respond_to?(:id)
      end
      created
    rescue QuotaExceededError
      []
    end

    private

    def call_newsapi(query, page_size)
      with_retry do
        response = HTTParty.get(BASE_URL, query: {
          q:         query,
          pageSize:  page_size,
          language:  "en",
          sortBy:    "publishedAt",
          apiKey:    api_key,
        }, timeout: 30)
        return [] unless response.success?
        Array(response.parsed_response["articles"])
      end
    end

    def ingest_record(query, article)
      url = article["url"].to_s
      return nil if url.empty?

      dedup_by_source_ref(source: "newsapi", ref: url) do
        body = [article["title"], article["description"], article["content"]].compact.join("\n\n")
        next nil if body.strip.empty?

        Document.create!(
          source:        "newsapi",
          source_ref:    url,
          doc_type:      "news",
          title:         article["title"],
          authors:       Array(article["author"]).compact,
          published_at:  safe_parse_time(article["publishedAt"]) || Time.current,
          raw_url:       url,
          raw_text:      body,
          word_count:    body.split.size,
          content_hash:  Digest::SHA256.hexdigest(body),
          metadata:      { query: query, source: article.dig("source", "name") },
        )
      end
    end

    def safe_parse_time(s)
      Time.parse(s.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def api_key
      ENV.fetch("NEWSAPI_KEY") { raise FetcherError, "NEWSAPI_KEY not set" }
    end
  end
end
