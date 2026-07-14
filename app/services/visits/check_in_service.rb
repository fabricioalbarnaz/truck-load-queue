module Visits
  class CheckInService
    def initialize(driver:, truck:, checked_in_by:)
      @driver = driver
      @truck = truck
      @checked_in_by = checked_in_by
    end

    def call
      reactivate_driver_truck_pairing!

      Visit.create(
        driver: @driver,
        truck: @truck,
        checked_in_by: @checked_in_by,
        entered_yard_at: Time.current
      )
    end

    private

    def reactivate_driver_truck_pairing!
      pairing = DriverTruck.find_or_initialize_by(driver: @driver, truck: @truck)
      pairing.update!(active: true) if pairing.new_record? || !pairing.active?
    end
  end
end
