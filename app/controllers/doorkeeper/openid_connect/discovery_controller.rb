module Doorkeeper
  module OpenidConnect
    class DiscoveryController < ::Doorkeeper::ApplicationController
      include Doorkeeper::Helpers::Controller

      WEBFINGER_RELATION = 'http://openid.net/specs/connect/1.0/issuer'.freeze

      def provider
        render json: provider_response
      end

      def webfinger
        render json: webfinger_response
      end

      def keys
        render json: keys_response
      end

      private

      def provider_response
        doorkeeper = ::Doorkeeper.configuration
        openid_connect = ::Doorkeeper::OpenidConnect.configuration
        {
          issuer: openid_connect.issuer,
          authorization_endpoint: oauth_authorization_url(protocol: protocol),
          token_endpoint: oauth_token_url(protocol: protocol),
          revocation_endpoint: oauth_revoke_url(protocol: protocol),
          introspection_endpoint: oauth_introspect_url(protocol: protocol),
          userinfo_endpoint: oauth_userinfo_url(protocol: protocol),
          jwks_uri: oauth_discovery_keys_url(protocol: protocol),
          end_session_endpoint: Doorkeeper::OpenidConnect.configuration.end_session_endpoint.call(),

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

          subject_types_supported: openid_connect.subject_types_supported,

          id_token_signing_alg_values_supported: [
            ::Doorkeeper::OpenidConnect.signing_algorithm
          ],

          claim_types_supported: [
            'normal',

            # TODO: support these
            #'aggregated',
            #'distributed',
          ],

          claims_supported: [
            'iss',
            'sub',
            'aud',
            'exp',
            'iat',
          ] | openid_connect.claims.to_h.keys,
        }.compact
      end

      def webfinger_response
        {
          subject: params.require(:resource),
          links: [
            {
              rel: WEBFINGER_RELATION,
              href: root_url(protocol: protocol),
            }
          ]
        }
      end

      def keys_response
        signing_key = Doorkeeper::OpenidConnect.signing_key_normalized

        {
          keys: [
            signing_key.merge(
              use: 'sig',
              alg: Doorkeeper::OpenidConnect.signing_algorithm
            )
          ]
        }
      end

      def protocol
        Doorkeeper::OpenidConnect.configuration.protocol.call
      end
    end
  end
end
