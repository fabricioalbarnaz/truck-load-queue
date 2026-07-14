class Visit < ApplicationRecord
  ACTIVE_STATUSES = %w[in_yard queued loading].freeze

  belongs_to :driver
  belongs_to :truck
  belongs_to :checked_in_by, class_name: "User"
  belongs_to :order_issued_by, class_name: "User", optional: true
  belongs_to :finished_by, class_name: "User", optional: true

  enum :status, { in_yard: "in_yard", queued: "queued", loading: "loading", finished: "finished" }, default: "in_yard"

  validates :entered_yard_at, presence: true
  validate :driver_has_no_other_active_visit
  validate :truck_has_no_other_active_visit

  scope :active_queue, -> { where(status: %w[queued loading]).order(:order_issued_at) }

  def queue_position
    return 0 if loading?

    Visit.where(status: :queued).where("order_issued_at < ?", order_issued_at).count + 1
  end

  private

  def driver_has_no_other_active_visit
    return unless driver_id && ACTIVE_STATUSES.include?(status)

    conflict = Visit.where(driver_id: driver_id, status: ACTIVE_STATUSES).where.not(id: id).exists?
    errors.add(:driver, :already_in_active_visit) if conflict
  end

  def truck_has_no_other_active_visit
    return unless truck_id && ACTIVE_STATUSES.include?(status)

    conflict = Visit.where(truck_id: truck_id, status: ACTIVE_STATUSES).where.not(id: id).exists?
    errors.add(:truck, :already_in_active_visit) if conflict
  end
end
