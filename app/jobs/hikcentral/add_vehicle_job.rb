module Hikcentral
  class AddVehicleJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(truck_id:, driver_id:)
      truck = Truck.find(truck_id)
      return if truck.hikcentral_synced_at.present?

      driver = Driver.find(driver_id)
      Hikcentral::AddVehicleService.new(truck: truck, driver: driver).call
    end
  end
end
