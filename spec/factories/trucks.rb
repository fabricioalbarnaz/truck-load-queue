FactoryBot.define do
  factory :truck do
    sequence(:plate) { |n| format("ABC%04d", n) }
    model { "Volvo FH 540" }
    capacity { 30 }
    active { true }
  end
end
