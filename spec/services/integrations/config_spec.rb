require "rails_helper"

RSpec.describe Integrations::Config do
  describe ".for" do
    around do |example|
      original = ENV["HIKCENTRAL_BASE_URL"]
      example.run
      ENV["HIKCENTRAL_BASE_URL"] = original
    end

    it "wraps the named integration's section with dot-access read from ENV" do
      ENV["HIKCENTRAL_BASE_URL"] = "https://hikcentral.example.com"

      config = described_class.for(:hikcentral)

      expect(config.base_url).to eq("https://hikcentral.example.com")
      expect(config).to respond_to(:app_key)
    end

    it "raises UnknownIntegrationError for a name not in config/integrations.yml" do
      expect { described_class.for(:not_a_real_integration) }
        .to raise_error(Integrations::Config::UnknownIntegrationError, /not_a_real_integration/)
    end
  end
end
