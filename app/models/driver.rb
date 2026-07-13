class Driver < ApplicationRecord
  NOTIFICATION_CHANNELS = %w[sms whatsapp both].freeze

  encrypts :cpf, deterministic: true
  encrypts :phone, deterministic: true

  has_many :driver_trucks, dependent: :destroy
  has_many :trucks, through: :driver_trucks

  enum :notification_channel, NOTIFICATION_CHANNELS.index_with(&:itself), default: "sms"

  validates :name, presence: true
  validates :cpf, presence: true, uniqueness: true
  validates :phone, presence: true, phone: true
  validate :cpf_must_be_valid

  scope :active, -> { where(active: true) }

  private

  def cpf_must_be_valid
    errors.add(:cpf, :invalid) if cpf.present? && !CPF.valid?(cpf)
  end
end
