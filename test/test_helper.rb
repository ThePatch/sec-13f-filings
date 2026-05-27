ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

class ActiveSupport::TestCase
  # Run tests serially — pgvector + raw-SQL inserts in the retrieval tests don't
  # round-trip through transactional fixtures cleanly, and parallel workers
  # would race on the shared chunks table.
  # parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
