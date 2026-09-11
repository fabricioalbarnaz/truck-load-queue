module Integrations
  # Generic accessor for config/integrations.yml. Rails' own config_for only
  # gives dot-access at the top level (the per-integration section itself
  # comes back as a plain symbol-keyed Hash), so #for wraps that section the
  # same way Rails wraps the top level, giving e.g. `.for(:hikcentral).base_url`.
  class Config
    class UnknownIntegrationError < StandardError; end

    def self.for(name)
      section = settings.fetch(name.to_sym) do
        raise UnknownIntegrationError, "unknown integration: #{name.inspect}"
      end

      ActiveSupport::OrderedOptions.new.update(section)
    end

    def self.settings
      Rails.application.config_for(:integrations)
    end
  end
end
