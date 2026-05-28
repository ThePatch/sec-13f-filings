require "digest"

module Ingest
  class GdeltNewsFetcher < BaseFetcher
    BASE_URL = "https://api.gdeltproject.org/api/v2/doc/doc".freeze

    def fetch_for_query(query, max_records: 75)
      respect_rate_limit("gdelt", requests_per_minute: 15)
      results = call_gdelt(query, max_records)
      created = []
      results.each do |r|
        doc = ingest_record(query, r)
        created << doc.id if doc&.respond_to?(:id)
      end
      created
    end

    def fetch_for_company(company)
      q = company.ticker.presence || company.name
      fetch_for_query("\"#{q}\"")
    end

    private

    def call_gdelt(query, max_records)
      with_retry do
        response = HTTParty.get(BASE_URL, query: {
          query:      query,
          mode:       "ArtList",
          format:     "json",
          maxrecords: max_records,
          sort:       "DateDesc",
          timespan:   "24h",
        }, headers: { "User-Agent" => ENV.fetch("SCRAPER_USER_AGENT", "F13ExplorerBot/1.0") }, timeout: 30)
        return [] unless response.success?
        parsed = response.parsed_response
        Array(parsed.is_a?(Hash) ? parsed["articles"] : nil)
      end
    rescue FetcherError
      []
    end

    def ingest_record(query, record)
      url = record["url"].to_s
      return nil if url.empty?

      dedup_by_source_ref(source: "gdelt", ref: url) do
        scrape = Ingest::NewsScraper.extract(url: url)
        title  = record["title"].presence || scrape[:title]
        text   = scrape[:ok] ? scrape[:text].to_s : title.to_s
        next nil if text.strip.empty?

        Document.create!(
          source:        "gdelt",
          source_ref:    url,
          doc_type:      "news",
          title:         title,
          authors:       [],
          published_at:  parse_seendate(record["seendate"]) || Time.current,
          raw_url:       url,
          raw_text:      text,
          word_count:    text.split.size,
          content_hash:  Digest::SHA256.hexdigest(text),
          metadata:      {
            query:                 query,
            domain:                record["domain"],
            extraction_failed:     !scrape[:ok],
            extraction_container:  scrape[:container],
          },
        )
      end
    end

    def parse_seendate(s)
      Time.strptime(s.to_s, "%Y%m%dT%H%M%SZ")
    rescue ArgumentError, TypeError
      nil
    end
  end
end
