ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/reporters"
require "factory_bot_rails"
require "shoulda/matchers"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  # DatabaseCleaner setup
  setup    { DatabaseCleaner.start }
  teardown { DatabaseCleaner.clean }

  DatabaseCleaner.strategy = :transaction
  DatabaseCleaner.clean_with :truncation
end
