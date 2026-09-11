FactoryBot.define do
  factory :feature_flag do
    key { "hikcentral" }
    enabled { false }

    # Feature flags are fixed reference data (only FeatureFlag::KEYS.size valid keys exist),
    # so reuse an existing row instead of colliding on the uniqueness validation.
    initialize_with { FeatureFlag.find_or_initialize_by(key: key) }

    FeatureFlag::KEYS.each do |flag_key|
      trait flag_key.to_sym do
        key { flag_key }
      end
    end
  end
end
