# app/jobs/open_figi_resolution_job.rb
# Wraps OpenFigiResolver as an ActiveJob (backed by delayed_job in this fork).
class OpenFigiResolutionJob < ApplicationJob
  queue_as :default

  def perform
    OpenFigiResolver.new.resolve_unresolved!
  end
end
