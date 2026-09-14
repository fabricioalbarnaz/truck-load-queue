require "rails_helper"

RSpec.describe Integrations::Config do
  describe ".for" do
    around do |example|
      keys = %w[HIKCENTRAL_BASE_URL HIKCENTRAL_VEHICLE_GROUP_INDEX_CODE]
      original = keys.index_with { |key| ENV[key] }
      example.run
      original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    it "wraps the named integration's section with dot-access read from ENV" do
      ENV["HIKCENTRAL_BASE_URL"] = "https://hikcentral.example.com"

      config = described_class.for(:hikcentral)

      expect(config.base_url).to eq("https://hikcentral.example.com")
      expect(config).to respond_to(:app_key)
    end

    it "keeps a numeric-looking ENV value as a String, not a YAML Integer" do
      ENV["HIKCENTRAL_VEHICLE_GROUP_INDEX_CODE"] = "1"

      config = described_class.for(:hikcentral)

      expect(config.vehicle_group_index_code).to eq("1")
      expect(config.vehicle_group_index_code).to be_a(String)
    end

    it "raises UnknownIntegrationError for a name not in config/integrations.yml" do
      expect { described_class.for(:not_a_real_integration) }
        .to raise_error(Integrations::Config::UnknownIntegrationError, /not_a_real_integration/)
    end
  end
end
