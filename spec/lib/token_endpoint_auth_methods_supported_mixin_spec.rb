# frozen_string_literal: true

require "rails_helper"

RSpec.describe Doorkeeper::OpenidConnect::TokenEndpointAuthMethodsSupportedMixin do
  subject(:host) do
    Class.new do
      include Doorkeeper::OpenidConnect::TokenEndpointAuthMethodsSupportedMixin
    end.new
  end

  describe "#token_endpoint_auth_methods_supported" do
    context "when Doorkeeper exposes the client authentication methods registry (doorkeeper#1840)" do
      # Doorkeeper >= the release shipping the registry returns
      # Doorkeeper::ClientAuthentication::Method objects whose `name` is already
      # the RFC 8414 identifier. We emulate that surface with doubles so the new
      # path can be exercised regardless of the installed Doorkeeper version
      # (CI/local currently track a Doorkeeper that predates the registry).
      def auth_method(name)
        double("Doorkeeper::ClientAuthentication::Method", name: name)
      end

      let(:doorkeeper_config) do
        instance = double("Doorkeeper::Config")
        allow(instance).to receive(:client_authentication_methods).and_return(
          [
            auth_method(:client_secret_basic),
            auth_method(:client_secret_post),
            auth_method(:none),
          ],
        )
        # The deprecated alias still exists on this Doorkeeper version; stub it
        # so we can assert it is *not* consulted.
        allow(instance).to receive(:client_credentials_methods)
        instance
      end

      before { allow(Doorkeeper).to receive(:config).and_return(doorkeeper_config) }

      it "uses the registry's RFC 8414 names verbatim" do
        expect(host.token_endpoint_auth_methods_supported)
          .to eq %w[client_secret_basic client_secret_post]
      end

      it "excludes the public client (none) pseudo-method" do
        expect(host.token_endpoint_auth_methods_supported).not_to include("none")
      end

      it "prefers the registry API over the deprecated client_credentials_methods alias" do
        host.token_endpoint_auth_methods_supported

        expect(doorkeeper_config).to have_received(:client_authentication_methods)
        expect(doorkeeper_config).not_to have_received(:client_credentials_methods)
      end

      it "preserves the configured order of the remaining methods" do
        allow(doorkeeper_config).to receive(:client_authentication_methods).and_return(
          [auth_method(:client_secret_post), auth_method(:client_secret_basic)],
        )

        expect(host.token_endpoint_auth_methods_supported)
          .to eq %w[client_secret_post client_secret_basic]
      end
    end

    context "when the installed Doorkeeper predates the registry" do
      # A bare double does not respond to `client_authentication_methods`, so
      # the `respond_to?` guard must fall back to translating the legacy
      # `client_credentials_methods` symbols through the mapping.
      let(:doorkeeper_config) do
        double("Doorkeeper::Config", client_credentials_methods: %i[from_basic from_params])
      end

      before { allow(Doorkeeper).to receive(:config).and_return(doorkeeper_config) }

      it "does not respond to the registry API in this emulation" do
        expect(doorkeeper_config).not_to respond_to(:client_authentication_methods)
      end

      it "translates the legacy method identifiers via the mapping" do
        expect(host.token_endpoint_auth_methods_supported)
          .to eq %w[client_secret_basic client_secret_post]
      end

      it "ignores unknown legacy identifiers" do
        allow(doorkeeper_config).to receive(:client_credentials_methods)
          .and_return(%i[from_basic something_custom])

        expect(host.token_endpoint_auth_methods_supported).to eq %w[client_secret_basic]
      end
    end
  end
end
