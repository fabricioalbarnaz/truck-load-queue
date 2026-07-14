class SendNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(visit_id:, event:)
    visit = Visit.find(visit_id)
    Notifications::NotifyDriverService.new(visit: visit, event: event).call
  end
end
