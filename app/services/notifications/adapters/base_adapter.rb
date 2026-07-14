module Notifications
  module Adapters
    class BaseAdapter
      def send_message(to:, body:)
        raise NotImplementedError, "#{self.class} must implement #send_message"
      end
    end
  end
end
