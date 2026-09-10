module Api
  class BaseController < ActionController::API
    before_action :authenticate_device!

    private

    def authenticate_device!
      head :unauthorized and return if expected_token.blank?

      token = provided_token
      head :unauthorized and return if token.blank?
      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
    end

    def provided_token
      request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
    end

    def expected_token
      ENV["EVENTS_INGEST_TOKEN"]
    end
  end
end
