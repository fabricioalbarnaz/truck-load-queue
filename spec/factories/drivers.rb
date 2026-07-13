FactoryBot.define do
  factory :driver do
    name { Faker::Name.name }
    cpf { CPF.generate }
    sequence(:phone) { |n| format("+551199%07d", n) }
    notification_channel { "sms" }
    active { true }
  end
end
