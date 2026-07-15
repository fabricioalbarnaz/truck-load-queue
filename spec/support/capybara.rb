require "capybara/cuprite"

# Registered under a name other than the gem's own default `:cuprite` key —
# `capybara-cuprite` registers its own `:cuprite` driver (with different
# defaults) as a side effect of being required, and it wins over a
# same-named re-registration here for reasons that weren't fully root
# caused. Using a distinct name sidesteps it entirely.
Capybara.register_driver(:app_cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1200, 800 ],
    browser_path: "/usr/bin/chromium",
    browser_options: { "no-sandbox" => nil },
    process_timeout: 20,
    timeout: 20
  )
end

Capybara.javascript_driver = :app_cuprite

# The default 2s implicit-wait can be too tight for a real browser + Turbo
# navigation chains (several page transitions in one example) under load —
# bump it rather than sprinkling explicit sleeps through specs.
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :app_cuprite
    WebMock.disable_net_connect!(allow_localhost: true)
    # A spec that used `Capybara.using_session(:public) { ... }` should
    # restore the default session as "current" once the block ends, but
    # specs earlier in a randomized run were occasionally leaving it
    # pointed at :public — forcing it back here makes every example start
    # from a known state regardless of what ran before it.
    Capybara.session_name = :default
  end
end
