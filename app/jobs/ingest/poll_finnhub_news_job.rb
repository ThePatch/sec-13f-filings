module Ingest
  class PollFinnhubNewsJob < ApplicationJob
    queue_as :default

    def perform
      tickers = watchlist_tickers
      return if tickers.empty?
      ids = Ingest::FinnhubNewsFetcher.new.fetch_for_tickers(tickers)
      ids.each { |id| ProcessDocumentJob.perform_later(id) }
      Rails.logger.info("[ingest.finnhub] new=#{ids.size}")
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
