module Visits
  class PromoteNextService
    def call
      next_visit = Visit.queued.order(:order_issued_at).first
      return unless next_visit

      next_visit.update(status: :loading, loading_started_at: Time.current)
      Notifications::NotifyDriverService.enqueue(visit: next_visit, event: :your_turn) if next_visit.errors.empty?
      next_visit
    end
  end
end
