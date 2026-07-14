module Notifications
  class Dispatcher
    REAL_ADAPTERS = {
      "sms" => Adapters::TwilioSmsAdapter,
      "whatsapp" => Adapters::TwilioWhatsappAdapter
    }.freeze

    def initialize(driver)
      @driver = driver
    end

    def deliver(body)
      channels.each do |channel|
        adapter_for(channel).new.send_message(to: @driver.phone, body: body)
      end
    end

    private

    def channels
      @driver.notification_channel == "both" ? %w[sms whatsapp] : [ @driver.notification_channel ]
    end

    def adapter_for(channel)
      Rails.application.config.x.notifications.adapter_class || REAL_ADAPTERS.fetch(channel)
    end
  end
end
