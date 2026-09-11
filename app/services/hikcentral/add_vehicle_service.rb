module Hikcentral
  class AddVehicleService
    VALIDITY_PERIOD = 5.years

    def self.enqueue(truck:, driver:)
      Hikcentral::AddVehicleJob.perform_later(truck_id: truck.id, driver_id: driver.id)
    end

    def initialize(truck:, driver:, client: Hikcentral::Client.new)
      @truck = truck
      @driver = driver
      @client = client
    end

    def call
      effective_date = Time.current

      @client.add_vehicle(
        plate_no: @truck.plate,
        person_given_name: @driver.name,
        phone_no: @driver.phone,
        effective_date: effective_date,
        expired_date: effective_date + VALIDITY_PERIOD
      )

      @truck.update!(hikcentral_synced_at: Time.current)
    end
  end
end
