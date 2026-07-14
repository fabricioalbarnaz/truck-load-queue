require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  # System specs drive a real browser against Capybara's local test server;
  # that traffic isn't a real external HTTP call and shouldn't need a cassette.
  config.ignore_localhost = true
end
