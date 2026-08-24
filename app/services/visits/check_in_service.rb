module Visits
  class CheckInService
    def initialize(driver:, truck:, checked_in_by:, order_number: nil)
      @driver = driver
      @truck = truck
      @checked_in_by = checked_in_by
      @order_number = order_number
    end

    def call
      @visit = Visit.new(
        driver: @driver,
        truck: @truck,
        checked_in_by: @checked_in_by,
        entered_yard_at: Time.current
      )

      ActiveRecord::Base.transaction do
        save_if_new(@driver) or raise ActiveRecord::Rollback
        save_if_new(@truck) or raise ActiveRecord::Rollback
        reactivate_driver_truck_pairing!
        @visit.save or raise ActiveRecord::Rollback
        issue_order! if @order_number.present?
        raise ActiveRecord::Rollback if @visit.errors.present?
      end

      @visit
    end

    private

    def issue_order!
      Visits::IssueOrderService.new(
        visit: @visit, order_issued_by: @checked_in_by, order_number: @order_number
      ).call
    end

    def save_if_new(record)
      record.new_record? ? record.save : true
    end

    def reactivate_driver_truck_pairing!
      pairing = DriverTruck.find_or_initialize_by(driver: @driver, truck: @truck)
      pairing.update!(active: true) if pairing.new_record? || !pairing.active?
    end
  end
end
