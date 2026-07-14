module Visits
  class FinishLoadingService
    def initialize(visit:, finished_by:)
      @visit = visit
      @finished_by = finished_by
    end

    def call
      @visit.update(status: :finished, finished_at: Time.current, finished_by: @finished_by)
      Visits::PromoteNextService.new.call if @visit.errors.empty?
      @visit
    end
  end
end
