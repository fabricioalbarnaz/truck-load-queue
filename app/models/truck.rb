class Truck < ApplicationRecord
  normalizes :plate, with: ->(plate) { plate.to_s.strip.upcase }

  has_many :driver_trucks, dependent: :destroy
  has_many :drivers, through: :driver_trucks

  validates :plate, presence: true, uniqueness: true
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
end
