class Role < ApplicationRecord
  KEYS = %w[admin registration_operator expedition_operator queue_operator].freeze

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :name, presence: true
end
