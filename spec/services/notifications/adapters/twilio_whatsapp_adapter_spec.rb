require "rails_helper"

RSpec.describe Notifications::Adapters::TwilioWhatsappAdapter do
  subject(:adapter) do
    described_class.new(account_sid: "ACtest0000000000000000000000000", auth_token: "authtoken", from: "+15005550006")
  end

  describe "#send_message" do
    it "sends a WhatsApp message through the Twilio REST API, prefixing numbers with whatsapp:",
      vcr: { cassette_name: "twilio_whatsapp_adapter/send_message" } do
      result = adapter.send_message(to: "+15551234567", body: "Sua vez chegou!")

      expect(result.status).to eq("queued")
      expect(result.to).to eq("whatsapp:+15551234567")
      expect(result.from).to eq("whatsapp:+15005550006")
    end
  end
end
