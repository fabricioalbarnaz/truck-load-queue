module Visits
  class PromoteNextService
    def call
      promoted = fill_loading_slot
      fill_getting_ready_slot
      promoted
    end

    private

    def fill_loading_slot
      return if Visit.loading.exists?

      next_visit = Visit.where(status: %w[getting_ready queued]).order(:order_issued_at).first
      return unless next_visit

      next_visit.update(status: :loading, loading_started_at: Time.current)
      Notifications::NotifyDriverService.enqueue(visit: next_visit, event: :your_turn) if next_visit.errors.empty?
      next_visit
    end

    def fill_getting_ready_slot
      return unless Visit.loading.exists?
      return if Visit.getting_ready.exists?

      next_visit = Visit.queued.order(:order_issued_at).first
      return unless next_visit

      next_visit.update(status: :getting_ready, getting_ready_at: Time.current)
      Notifications::NotifyDriverService.enqueue(visit: next_visit, event: :get_ready) if next_visit.errors.empty?
      next_visit
    end
  end
end
