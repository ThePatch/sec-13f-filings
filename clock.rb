require "./config/boot"
require "./config/environment"

require "clockwork"
include Clockwork

module Clockwork
  configure do |config|
    config[:tz] = "America/New_York"
  end
end

every(1.day, "download filings", at: "05:00") do
  today_in_nyc = Time.zone.now.in_time_zone("America/New_York").to_date
  date = today_in_nyc - 1.day
  quarter = (date.month - 1) / 3 + 1

  ThirteenF.delay(priority: 100).import_and_process_filings!(date.year, quarter)
end

every(30.minutes, "download latest filings", at: ["**:15", "**:45"]) do
  current_hour = Time.zone.now.in_time_zone("America/New_York").hour
  next unless (7..20).include?(current_hour)

  ThirteenF.delay(priority: 50).import_and_process_most_recent_filings!
end

every(1.day, "make sure materialized views are up to date", at: "23:00") do
  ThirteenFFiler.delay(priority: 10).refresh!
  CompanyCusipLookup.delay(priority: 10).refresh!
  CusipQuarterlyFilingsCount.delay(priority: 100).refresh!
end

every(1.hour, "generate insights") do
  # GenerateInsightsJob is an ActiveJob backed by delayed_job in this fork,
  # so we enqueue via perform_later (mirrors how SecTickerSyncJob would run).
  GenerateInsightsJob.set(priority: 75).perform_later
end

# ─── v2 ingestion + atom maintenance (Phase 10) ───────────────────────
every(5.minutes, "poll sec edgar") do
  Ingest::PollSecEdgarJob.set(priority: 80).perform_later
end

every(15.minutes, "poll gdelt news") do
  Ingest::PollGdeltNewsJob.set(priority: 60).perform_later
end

every(1.hour, "poll finnhub news") do
  Ingest::PollFinnhubNewsJob.set(priority: 60).perform_later
end

every(1.day, "poll alphavantage earnings", at: "06:00") do
  Ingest::PollAlphavantageEarningsJob.set(priority: 70).perform_later
end

every(6.hours, "purge newsapi raw text") do
  Ingest::PurgeNewsApiRawTextJob.set(priority: 90).perform_later
end

every(1.hour, "atom decay") do
  Atoms::DecayJob.set(priority: 85).perform_later
end
