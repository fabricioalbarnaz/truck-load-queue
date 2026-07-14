RSpec.configure do |config|
  config.before do
    Notifications::Adapters::TestAdapter.clear!
  end
end
