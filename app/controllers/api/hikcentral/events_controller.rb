module Api
  module Hikcentral
    class EventsController < Api::BaseController
      def create
        result = Events::Adapters::HikcentralAdapter.new(params.to_unsafe_h).call

        # HikCentral's OpenAPI guide (section 4.3.3) requires exactly HTTP 200 on
        # receipt, or it considers the push failed and retries every 24 hours —
        # unlike the generic /api/events endpoint, 202 Accepted isn't honored here.
        render json: {
          accepted: result[:accepted].map { |event| { id: event.id, status: event.status } },
          skipped: result[:skipped_count]
        }, status: :ok
      rescue Events::Adapters::HikcentralAdapter::InvalidPushError => e
        render json: { errors: [ e.message ] }, status: :unprocessable_content
      end

      private

      # HikCentral's event-push mechanism sends the shared secret via a plain `Token` header
      # (not `Authorization: Bearer`, which it doesn't support configuring) — Rack surfaces an
      # incoming `Token` header as env/request.headers key `HTTP_TOKEN`.
      def provided_token
        request.headers["HTTP_TOKEN"].to_s.strip
      end
    end
  end
end
