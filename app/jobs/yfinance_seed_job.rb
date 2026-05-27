# app/jobs/yfinance_seed_job.rb
# Wraps YfinanceSeed as an ActiveJob (backed by delayed_job in this fork).
class YfinanceSeedJob < ApplicationJob
  queue_as :default

  def perform
    YfinanceSeed.new.call
  end
end
