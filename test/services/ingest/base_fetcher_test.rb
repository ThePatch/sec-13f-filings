require 'test_helper'

module Ingest
  class BaseFetcherTest < ActiveSupport::TestCase
    class TestSubclass < BaseFetcher; end

    def setup
      @prev_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      @fetcher = TestSubclass.new
    end

    def teardown
      Rails.cache = @prev_cache
    end

    test 'respect_rate_limit raises when over the per-minute ceiling' do
      3.times { @fetcher.respect_rate_limit("test", requests_per_minute: 3) }
      assert_raises(BaseFetcher::RateLimitedError) do
        @fetcher.respect_rate_limit("test", requests_per_minute: 3)
      end
    end

    test 'track_quota raises when over daily cap' do
      assert_raises(BaseFetcher::QuotaExceededError) do
        @fetcher.track_quota("dailylim", used: 26, daily_limit: 25)
      end
    end

    test 'dedup_by_source_ref returns existing document without yielding' do
      doc = Document.create!(
        doc_type: "news", source: "dedup", source_ref: "abc",
        title: "x", published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: "x",
      )
      called = false
      result = @fetcher.dedup_by_source_ref(source: "dedup", ref: "abc") do
        called = true
        Document.create!
      end
      assert_equal doc.id, result.id
      refute called, "block should not have been called"
    ensure
      Document.where(id: doc&.id).delete_all if doc
    end

    test 'dedup_by_source_ref yields when not previously inserted' do
      called = false
      @fetcher.dedup_by_source_ref(source: "dedup", ref: "fresh-#{SecureRandom.hex(4)}") do
        called = true
        nil
      end
      assert called
    end

    test 'with_retry retries on transient errors and finally raises' do
      attempts = 0
      assert_raises(BaseFetcher::FetcherError) do
        @fetcher.with_retry(max: 3, base_delay: 0) do
          attempts += 1
          raise BaseFetcher::RateLimitedError, "boom"
        end
      end
      assert_equal 3, attempts
    end
  end
end
