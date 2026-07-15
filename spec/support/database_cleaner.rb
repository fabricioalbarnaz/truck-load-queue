require "database_cleaner/active_record"

RSpec.configure do |config|
  config.before(:suite) do
    # Docker Compose's DATABASE_URL points at the `db` service hostname, not
    # localhost — DatabaseCleaner's safeguard treats that as "remote" and
    # refuses to run by default. Safe to bypass: RAILS_ENV is always test
    # here (config/environment.rb aborts otherwise, see rails_helper.rb).
    DatabaseCleaner.allow_remote_database_url = true
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  # System specs drive a real browser hitting the app through a separate
  # Capybara server thread/connection — a wrapping transaction on the spec's
  # own connection is invisible to it, so truncation (real commits, real
  # cleanup after) is used instead.
  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
