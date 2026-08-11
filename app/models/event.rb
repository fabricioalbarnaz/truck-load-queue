class Event < ApplicationRecord
  enum :status, { pending: "pending", processed: "processed", failed: "failed" }, default: "pending"

  validates :event_type, presence: true
  validates :received_at, presence: true

  scope :for_type, ->(event_type) { where(event_type: event_type) }
end
