# Shared primitives for every ingestion fetcher: HTTP retry, per-source
# per-minute rate limiting, daily quota accounting, dedup-by-source-ref.
#
# Counters live in Rails.cache (default: memory_store in dev, file_store in
# prod via the v1 setup). Single-box deployment makes that adequate; if you
# scale to multiple workers, swap the cache backend for Redis without changing
# this file.
require "httparty"

module Ingest
  class BaseFetcher
    class RateLimitedError < StandardError; end
    class QuotaExceededError < StandardError; end
    class FetcherError       < StandardError; end

    DEFAULT_HEADERS = { "Accept" => "application/json" }.freeze

    def with_retry(max: 3, base_delay: 1.0)
      attempt = 0
      begin
        attempt += 1
        yield
      rescue Net::OpenTimeout, Net::ReadTimeout, HTTParty::ResponseError,
             SocketError, RateLimitedError => e
        if attempt < max
          sleep(base_delay * (2**(attempt - 1)))
          retry
        end
        raise FetcherError, "retry exhausted: #{e.class}: #{e.message}"
      end
    end

    def respect_rate_limit(source, requests_per_minute:)
      key   = "rate_limit:#{source}:#{Time.current.to_i / 60}"
      count = Rails.cache.read(key) || 0
      raise RateLimitedError, "rate limit exceeded for #{source} (#{count}/#{requests_per_minute})" if count >= requests_per_minute
      Rails.cache.write(key, count + 1, expires_in: 90.seconds)
    end

    def track_quota(source, used: 1, daily_limit: nil)
      key   = "quota:#{source}:#{Date.today.iso8601}"
      count = Rails.cache.read(key) || 0
      Rails.cache.write(key, count + used, expires_in: 36.hours)
      if daily_limit && count + used > daily_limit
        raise QuotaExceededError, "daily quota of #{daily_limit} exceeded for #{source}"
      end
    end

    # Yields the block only if no document with (source, source_ref) exists.
    # Returns the (existing or newly-yielded) Document.
    def dedup_by_source_ref(source:, ref:)
      existing = Document.find_by(source: source, source_ref: ref)
      return existing if existing
      yield
    end

    def sec_user_agent
      ENV.fetch("SEC_USER_AGENT", "F13 Explorer admin@example.com")
    end
  end
end
