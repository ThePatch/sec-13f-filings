module Ingest
  class PollAlphavantageEarningsJob < ApplicationJob
    queue_as :default

    def perform
      tickers = watchlist_tickers
      return if tickers.empty?
      ids = Ingest::AlphavantageEarningsFetcher.new.fetch_for_watchlist(tickers)
      ids.each { |id| ProcessDocumentJob.perform_later(id) }
      Rails.logger.info("[ingest.alphavantage] new=#{ids.size}")
    end

    private

    def watchlist_tickers
      Watchlist.pluck(:cusips).flatten.uniq.compact
               .map { |c| Company.find_by(cusip: c)&.ticker }
               .compact.first(25)
    rescue StandardError
      []
    end
  end
end
