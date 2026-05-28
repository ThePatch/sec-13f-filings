module Ingest
  class PollGdeltNewsJob < ApplicationJob
    queue_as :default

    def perform
      tickers = watchlist_tickers
      return if tickers.empty?

      ids = tickers.flat_map do |t|
        company = Company.find_by(ticker: t)
        company ? Ingest::GdeltNewsFetcher.new.fetch_for_company(company) : []
      end
      ids.each { |id| ProcessDocumentJob.perform_later(id) }
      Rails.logger.info("[ingest.gdelt] new=#{ids.size}")
    end

    private

    def watchlist_tickers
      Watchlist.pluck(:cusips).flatten.uniq.compact
               .map { |c| Company.find_by(cusip: c)&.ticker }
               .compact.first(50)
    rescue StandardError
      []
    end
  end
end
