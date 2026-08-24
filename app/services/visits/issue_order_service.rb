module Visits
  class IssueOrderService
    def initialize(visit:, order_issued_by:, order_number:)
      @visit = visit
      @order_issued_by = order_issued_by
      @order_number = order_number
    end

    def call
      status = queue_empty? ? :loading : :queued

      attributes = {
        order_number: @order_number,
        order_issued_at: Time.current,
        order_issued_by: @order_issued_by,
        status: status
      }
      attributes[:loading_started_at] = Time.current if status == :loading

      @visit.update(attributes)
      Notifications::NotifyDriverService.enqueue(visit: @visit, event: :your_turn) if status == :loading && @visit.errors.empty?
      @visit
    end

    private

    def queue_empty?
      Visit.where(status: %w[queued loading]).where.not(id: @visit.id).none?
    end
  end
end
