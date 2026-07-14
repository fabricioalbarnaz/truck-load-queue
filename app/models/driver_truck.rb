class DriverTruck < ApplicationRecord
  belongs_to :driver
  belongs_to :truck

  validates :truck_id, uniqueness: { scope: :driver_id }

  scope :active, -> { where(active: true) }
end
