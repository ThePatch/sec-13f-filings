# One-off historical fetch for a single company. Enqueued when a CUSIP is
# added to a watchlist. Pulls:
#   - all 8-K / 10-Q / DEF 14A from the last 24 months
#   - last 4 earnings call transcripts (AlphaVantage)
#   - top GDELT news from the last 6 months
#
# Status is surfaced via a BackfillStatus row keyed on company_id so the UI
# (T-602) can poll progress.
module Ingest
  class BackfillCompanyJob < ApplicationJob
    queue_as :default

    def perform(company_id)
      company = Company.find_by(id: company_id)
      return unless company

      status = BackfillStatus.find_or_create_by(company_id: company.id) do |s|
        s.state = "pending"
        s.started_at = Time.current
      end
      status.update!(state: "running", started_at: Time.current)

      docs = { sec: 0, earnings: 0, news: 0 }

      docs[:sec]      = safely { run_sec(company) }
      docs[:earnings] = safely { run_earnings(company) }
      docs[:news]     = safely { run_news(company) }

      total = docs.values.sum
      docs.each do |k, count|
        Document.where(company_id: company.id, source: source_for_bucket(k))
                .order(ingested_at: :desc)
                .limit(count)
                .pluck(:id)
                .each { |id| ProcessDocumentJob.perform_later(id) }
      end

      status.update!(
        state:        "done",
        finished_at:  Time.current,
        document_count: total,
        breakdown:    docs.transform_keys(&:to_s),
      )
    rescue => e
      status&.update!(state: "failed", finished_at: Time.current, last_error: e.message)
      raise
    end

    private

    def safely
      yield.to_i
    rescue => e
      Rails.logger.warn("[backfill] step failed: #{e.class}: #{e.message}")
      0
    end

    def run_sec(company)
      Ingest::SecFilingFetcher.new.fetch_recent(since: 24.months.ago).size
    end

    def run_earnings(company)
      return 0 unless company.ticker
      Ingest::AlphavantageEarningsFetcher.new.fetch_for_watchlist([company.ticker]).size
    end

    def run_news(company)
      Ingest::GdeltNewsFetcher.new.fetch_for_company(company).size
    end

    def source_for_bucket(bucket)
      { sec: "sec", earnings: "alphavantage", news: "gdelt" }.fetch(bucket)
    end
  end
end
