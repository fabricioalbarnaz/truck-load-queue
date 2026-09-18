module Visits
  class IssueOrderService
    def initialize(visit:, order_issued_by:, order_number:)
      @visit = visit
      @order_issued_by = order_issued_by
      @order_number = order_number
    end

    def call
      ActiveRecord::Base.transaction do
        @visit.update(
          order_number: @order_number,
          order_issued_at: Time.current,
          order_issued_by: @order_issued_by,
          status: :queued
        )
        Visits::PromoteNextService.new.call if @visit.errors.empty?
      end

      @visit.reload if @visit.errors.empty?
      @visit
    end
  end
end
