module Ingest
  class PollSecEdgarJob < ApplicationJob
    queue_as :default

    def perform
      ids = Ingest::SecFilingFetcher.new.fetch_recent(since: 1.hour.ago)
      ids.each { |id| ProcessDocumentJob.perform_later(id) }
      Rails.logger.info("[ingest.sec] new=#{ids.size}")
    end
  end
end
