require "rails_helper"

RSpec.describe FeatureFlag, type: :model do
  subject { build(:feature_flag) }

  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_uniqueness_of(:key) }
  it { is_expected.to validate_inclusion_of(:key).in_array(FeatureFlag::KEYS) }

  describe ".enabled?" do
    it "returns false when no row exists for a valid key" do
      expect(FeatureFlag.enabled?(:hikcentral)).to be false
    end

    it "returns true when the row is enabled" do
      create(:feature_flag, key: "hikcentral", enabled: true)

      expect(FeatureFlag.enabled?(:hikcentral)).to be true
    end

    it "returns false when the row is disabled" do
      create(:feature_flag, key: "hikcentral", enabled: false)

      expect(FeatureFlag.enabled?(:hikcentral)).to be false
    end

    it "raises on an unregistered key" do
      expect { FeatureFlag.enabled?(:bogus) }.to raise_error(ArgumentError)
    end
  end

  describe ".enable!" do
    it "creates and enables a row when none exists" do
      expect { FeatureFlag.enable!(:hikcentral) }
        .to change { FeatureFlag.enabled?(:hikcentral) }.from(false).to(true)
    end

    it "enables an existing disabled row" do
      create(:feature_flag, key: "hikcentral", enabled: false)

      FeatureFlag.enable!(:hikcentral)

      expect(FeatureFlag.enabled?(:hikcentral)).to be true
    end
  end

  describe ".disable!" do
    it "disables an existing enabled row" do
      create(:feature_flag, key: "hikcentral", enabled: true)

      FeatureFlag.disable!(:hikcentral)

      expect(FeatureFlag.enabled?(:hikcentral)).to be false
    end
  end
end
