require "rails_helper"

RSpec.describe Notifications::Dispatcher do
  describe "#deliver" do
    it "sends through the configured test adapter for a driver with a single channel" do
      driver = create(:driver, notification_channel: "sms", phone: "+5511911111111")

      described_class.new(driver).deliver("Sua vez chegou!")

      expect(Notifications::Adapters::TestAdapter.messages).to contain_exactly(
        { to: "+5511911111111", body: "Sua vez chegou!" }
      )
    end

    it "sends once per channel for a driver on both channels" do
      driver = create(:driver, notification_channel: "both", phone: "+5511922222222")

      described_class.new(driver).deliver("Sua vez chegou!")

      expect(Notifications::Adapters::TestAdapter.messages.size).to eq(2)
      expect(Notifications::Adapters::TestAdapter.messages).to all(
        include(to: "+5511922222222", body: "Sua vez chegou!")
      )
    end

    it "uses the real per-channel Twilio adapters when no test adapter is configured" do
      driver = create(:driver, notification_channel: "sms", phone: "+5511933333333")
      original_adapter_class = Rails.application.config.x.notifications.adapter_class
      Rails.application.config.x.notifications.adapter_class = nil
      sms_adapter = instance_double(Notifications::Adapters::TwilioSmsAdapter, send_message: true)
      allow(Notifications::Adapters::TwilioSmsAdapter).to receive(:new).and_return(sms_adapter)

      described_class.new(driver).deliver("Sua vez chegou!")

      expect(sms_adapter).to have_received(:send_message).with(to: "+5511933333333", body: "Sua vez chegou!")
    ensure
      Rails.application.config.x.notifications.adapter_class = original_adapter_class
    end
  end
end
