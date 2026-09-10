module Api
  class EventsController < BaseController
    def create
      Rails.logger.info(params.to_unsafe_h)
      event = Events::IngestEventService.new(
        event_type: params[:event_type],
        device_id: params[:device_id],
        occurred_at: params[:occurred_at],
        payload: params.fetch(:data, {}).to_unsafe_h
      ).call

      if event.persisted?
        render json: { id: event.id, status: event.status }, status: :accepted
      else
        render json: { errors: event.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
