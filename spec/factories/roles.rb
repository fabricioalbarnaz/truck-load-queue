FactoryBot.define do
  factory :role do
    key { "admin" }
    name { key.to_s.titleize }

    # Roles are fixed reference data (only Role::KEYS.size valid keys exist),
    # so reuse an existing row instead of colliding on the uniqueness validation.
    initialize_with { Role.find_or_initialize_by(key: key) }

    Role::KEYS.each do |role_key|
      trait role_key.to_sym do
        key { role_key }
      end
    end
  end
end
