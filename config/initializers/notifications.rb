# Real Twilio notifications are only ever sent in production. Every other
# environment routes through the in-memory TestAdapter so a driver never
# gets a real SMS/WhatsApp message by accident.
#
# Deferred to `to_prepare` (rather than assigned directly here) because
# referencing an autoloadable app/ constant this early — before every
# engine (turbo-rails, importmap-rails, action_text) has finished
# registering its own autoload/eager_load paths — freezes those path
# arrays prematurely and crashes boot with `FrozenError: can't modify
# frozen Array` inside `Rails::Engine#unshift`.
Rails.application.config.to_prepare do
  Rails.application.config.x.notifications.adapter_class =
    Rails.env.production? ? nil : Notifications::Adapters::TestAdapter
end
