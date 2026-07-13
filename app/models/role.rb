class Role < ApplicationRecord
  KEYS = %w[admin cadastro expedicao fila].freeze

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :name, presence: true
end
