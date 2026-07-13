class User < ApplicationRecord
  # No :registerable — users are created only by an admin via Avo.
  devise :database_authenticatable, :recoverable, :rememberable,
         :validatable, :trackable, :lockable

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  validates :name, presence: true

  def role?(key)
    roles.exists?(key: key.to_s)
  end

  def admin?
    role?(:admin)
  end
end
