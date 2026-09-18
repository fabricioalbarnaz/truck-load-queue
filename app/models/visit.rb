class Visit < ApplicationRecord
  ACTIVE_STATUSES = %w[in_yard queued getting_ready loading].freeze
  PUBLIC_QUEUE_RELEVANT_STATUSES = %w[queued getting_ready loading finished].freeze

  STATUS_LABELS = {
    "in_yard" => "No pátio",
    "queued" => "Na fila",
    "getting_ready" => "Prepare-se",
    "loading" => "Carregando",
    "finished" => "Finalizado"
  }.freeze

  belongs_to :driver
  belongs_to :truck
  belongs_to :checked_in_by, class_name: "User"
  belongs_to :order_issued_by, class_name: "User", optional: true
  belongs_to :finished_by, class_name: "User", optional: true

  enum :status, {
    in_yard: "in_yard", queued: "queued", getting_ready: "getting_ready", loading: "loading", finished: "finished"
  }, default: "in_yard"

  validates :entered_yard_at, presence: true
  validates :order_number, presence: true, unless: :in_yard?
  validate :driver_has_no_other_active_visit
  validate :truck_has_no_other_active_visit

  scope :active_queue, -> { where(status: %w[queued getting_ready loading]).order(:order_issued_at) }

  after_commit :broadcast_public_queue!, if: :public_queue_relevant_change?

  def queue_position
    return 0 if loading?

    Visit.where(status: %w[queued getting_ready]).where("order_issued_at < ?", order_issued_at).count + 1
  end

  def status_label
    STATUS_LABELS.fetch(status)
  end

  private

  def public_queue_relevant_change?
    saved_change_to_status? &&
      (PUBLIC_QUEUE_RELEVANT_STATUSES.include?(status) ||
        PUBLIC_QUEUE_RELEVANT_STATUSES.include?(status_before_last_save))
  end

  def broadcast_public_queue!
    Turbo::StreamsChannel.broadcast_replace_to(
      "public_queue",
      target: "public_queue",
      partial: "public/queue/board",
      locals: {
        loading: Visit.loading.first,
        getting_ready: Visit.getting_ready.first,
        queued: Visit.active_queue.queued
      }
    )
  end

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
