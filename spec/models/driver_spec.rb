require "rails_helper"

RSpec.describe Driver, type: :model do
  subject { build(:driver) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:cpf) }
  it { is_expected.to validate_presence_of(:phone) }
  it { is_expected.to have_many(:driver_trucks).dependent(:destroy) }
  it { is_expected.to have_many(:trucks).through(:driver_trucks) }
  it {
    is_expected.to define_enum_for(:notification_channel)
      .with_values(Driver::NOTIFICATION_CHANNELS.index_with(&:itself))
      .backed_by_column_of_type(:string)
  }

  it "is valid with a valid CPF" do
    expect(build(:driver, cpf: CPF.generate)).to be_valid
  end

  it "is invalid with a malformed CPF" do
    expect(build(:driver, cpf: "11111111111")).not_to be_valid
  end

  it "is invalid with a duplicate CPF" do
    existing = create(:driver)
    expect(build(:driver, cpf: existing.cpf)).not_to be_valid
  end

  it "is invalid with a non E.164 phone" do
    expect(build(:driver, phone: "not-a-phone")).not_to be_valid
  end

  it "encrypts cpf and phone at rest" do
    driver = create(:driver, cpf: CPF.generate, phone: "+5511999999999")

    raw = ActiveRecord::Base.connection.select_one(
      "SELECT cpf, phone FROM drivers WHERE id = #{driver.id}"
    )

    expect(raw["cpf"]).not_to eq(driver.cpf)
    expect(raw["phone"]).not_to eq(driver.phone)
  end
end
