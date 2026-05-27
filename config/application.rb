require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sec13fFilings
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # v2 migrations introduce pgvector, generated columns, HNSW indexes and
    # Postgres enums — none of which round-trip cleanly through schema.rb.
    # Switch to structure.sql so the schema dump captures everything.
    config.active_record.schema_format = :sql
  end
end
