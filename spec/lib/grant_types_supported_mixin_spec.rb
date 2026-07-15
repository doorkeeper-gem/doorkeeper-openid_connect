# frozen_string_literal: true

require "rails_helper"

RSpec.describe Doorkeeper::OpenidConnect::GrantTypesSupportedMixin do
  subject(:host) do
    Class.new do
      include Doorkeeper::OpenidConnect::GrantTypesSupportedMixin
    end.new
  end

  describe "#grant_types_supported" do
    def doorkeeper_config(grant_flows:, refresh_token_enabled:)
      double("Doorkeeper::Config", grant_flows: grant_flows, refresh_token_enabled?: refresh_token_enabled)
    end

    it "returns the configured grant flows as-is when refresh tokens are disabled" do
      config = doorkeeper_config(grant_flows: %w[authorization_code implicit_oidc], refresh_token_enabled: false)

      expect(host.grant_types_supported(config)).to eq %w[authorization_code implicit_oidc]
    end

    it "appends refresh_token when use_refresh_token is enabled" do
      config = doorkeeper_config(grant_flows: %w[authorization_code], refresh_token_enabled: true)

      expect(host.grant_types_supported(config)).to eq %w[authorization_code refresh_token]
    end

    it "does not duplicate refresh_token when it is also listed in grant_flows" do
      config = doorkeeper_config(grant_flows: %w[authorization_code refresh_token], refresh_token_enabled: true)

      expect(host.grant_types_supported(config)).to eq %w[authorization_code refresh_token]
    end

    it "keeps an explicitly listed refresh_token when use_refresh_token is disabled" do
      config = doorkeeper_config(grant_flows: %w[authorization_code refresh_token], refresh_token_enabled: false)

      expect(host.grant_types_supported(config)).to eq %w[authorization_code refresh_token]
    end

    it "does not mutate the configured grant_flows array" do
      grant_flows = %w[authorization_code]
      config = doorkeeper_config(grant_flows: grant_flows, refresh_token_enabled: true)

      host.grant_types_supported(config)

      expect(grant_flows).to eq %w[authorization_code]
    end
  end
end
