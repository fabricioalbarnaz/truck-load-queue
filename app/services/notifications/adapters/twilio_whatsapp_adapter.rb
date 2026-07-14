module Notifications
  module Adapters
    class TwilioWhatsappAdapter < BaseAdapter
      def initialize(
        account_sid: ENV["TWILIO_ACCOUNT_SID"],
        auth_token: ENV["TWILIO_AUTH_TOKEN"],
        from: ENV["TWILIO_WHATSAPP_FROM"]
      )
        @account_sid = account_sid
        @auth_token = auth_token
        @from = from
      end

      def send_message(to:, body:)
        client.messages.create(from: "whatsapp:#{@from}", to: "whatsapp:#{to}", body: body)
      end

      private

      def client
        @client ||= Twilio::REST::Client.new(@account_sid, @auth_token)
      end
    end
  end
end
