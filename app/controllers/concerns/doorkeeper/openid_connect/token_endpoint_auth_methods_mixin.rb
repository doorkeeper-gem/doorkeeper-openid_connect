# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module TokenEndpointAuthMethodsMixin
      private

      # Maps Doorkeeper's client_credentials configuration to OIDC auth method names.
      # Shared by DiscoveryController and DynamicClientRegistrationController
      # to keep advertised and accepted auth methods in sync.
      AUTH_METHOD_MAPPING = {
        from_basic: 'client_secret_basic',
        from_params: 'client_secret_post',
      }.freeze

      def token_endpoint_auth_methods_supported(doorkeeper = ::Doorkeeper.configuration)
        doorkeeper.client_credentials_methods.filter_map { |method| AUTH_METHOD_MAPPING[method] }
      end
    end
  end
end
