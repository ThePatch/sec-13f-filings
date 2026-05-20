# app/jobs/sec_ticker_sync_job.rb
# Wraps SecTickerSync as an ActiveJob (backed by delayed_job in this fork).
class SecTickerSyncJob < ApplicationJob
  queue_as :default

  def perform
    SecTickerSync.new.call
  end
end
