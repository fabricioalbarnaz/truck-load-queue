class FeatureFlag < ApplicationRecord
  KEYS = %w[hikcentral].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }

  def self.enabled?(key)
    key = key.to_s
    raise ArgumentError, "unknown feature flag: #{key.inspect}" unless KEYS.include?(key)

    where(key: key, enabled: true).exists?
  end

  def self.enable!(key)
    find_or_initialize_by(key: key.to_s).update!(enabled: true)
  end

  def self.disable!(key)
    find_or_initialize_by(key: key.to_s).update!(enabled: false)
  end
end
