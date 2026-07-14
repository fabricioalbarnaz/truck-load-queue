module Notifications
  module Adapters
    class TestAdapter < BaseAdapter
      class << self
        def messages
          @messages ||= []
        end

        def clear!
          messages.clear
        end
      end

      def send_message(to:, body:)
        self.class.messages << { to: to, body: body }
        Rails.logger.info("[Notifications::Adapters::TestAdapter] to=#{to} body=#{body}")
      end
    end
  end
end
