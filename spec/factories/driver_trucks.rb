FactoryBot.define do
  factory :driver_truck do
    driver
    truck
    active { true }
  end
end
