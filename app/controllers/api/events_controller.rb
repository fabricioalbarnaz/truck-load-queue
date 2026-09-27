module Api
  class EventsController < BaseController
    def create
      # raw_body = request.raw_post

      Rails.logger.info(JSON.parse(params[:mixedTargetDetection])) if params[:mixedTargetDetection].present?
      # Rails.logger.info(
      #   "[Hikvision] evento recebido " \
      #   "content_type=#{request.content_type} " \
      #   "bytes=#{raw_body.bytesize} " \
      #   "remote_ip=#{request.remote_ip}"
      #  )

      head :ok
      # event = Events::IngestEventService.new(
      #   event_type: params[:event_type],
      #   device_id: params[:device_id],
      #   occurred_at: params[:occurred_at],
      #   payload: params.fetch(:data, {}).to_unsafe_h
      # ).call

      # if event.persisted?
      #   render json: { id: event.id, status: event.status }, status: :accepted
      # else
      #   render json: { errors: event.errors.full_messages }, status: :unprocessable_content
      # end
    end
  end
end
