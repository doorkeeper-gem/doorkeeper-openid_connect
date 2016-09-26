module Doorkeeper
  module OpenidConnect
    class DiscoveryController < ::Doorkeeper::ApplicationController
      include Doorkeeper::Helpers::Controller

      def show
        render json: provider_configuration
      end

      private

      def provider_configuration
        doorkeeper = ::Doorkeeper.configuration
        openid_connect = ::Doorkeeper::OpenidConnect.configuration

        {
          issuer: openid_connect.issuer,
          authorization_endpoint: oauth_authorization_url(protocol: :https),
          token_endpoint: oauth_token_url(protocol: :https),
          userinfo_endpoint: oauth_userinfo_url(protocol: :https),

          # TODO: implement controller
          #jwks_uri: oauth_keys_url(protocol: :https),

          scopes_supported: doorkeeper.scopes,

          # TODO: support id_token response type
          response_types_supported: doorkeeper.authorization_response_types,
          response_modes_supported: [ 'query', 'fragment' ],

          token_endpoint_auth_methods_supported: [
            'client_secret_basic',
            'client_secret_post',

            # TODO: look into doorkeeper-jwt_assertion for these
            #'client_secret_jwt',
            #'private_key_jwt'
          ],

          # TODO: make this configurable
          subject_types_supported: [
            'public',
          ],

          # TODO: make this configurable
          id_token_signing_alg_values_supported: [
            'RS256',
          ],
        }
      end
    end
  end
end
