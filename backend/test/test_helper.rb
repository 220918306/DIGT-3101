require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_group "Models",      "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services",    "app/services"
  add_group "Jobs",        "app/jobs"
  add_group "Factories",   "app/factories"
end

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

  # Appointment validation uses Time.zone (America/Toronto). Date#to_datetime.change(hour:)
  # builds UTC-ish values that can fall outside 9–17 local and flake; use this instead.
  def appointment_time_on(date, hour)
    Time.zone.local(date.year, date.month, date.day, hour, 0, 0)
  end

  # DatabaseCleaner setup
  setup    { DatabaseCleaner.start }
  teardown { DatabaseCleaner.clean }

  DatabaseCleaner.strategy = :transaction
  DatabaseCleaner.clean_with :truncation
end
