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
          authorization_endpoint: oauth_authorization_url,
          token_endpoint: oauth_token_url,
          userinfo_endpoint: oauth_userinfo_url,
          jwks_uri: oauth_discovery_keys_url,

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
            openid_connect.jws_signature_alg,
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
        }
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
        signing_key = Doorkeeper::OpenidConnect.signing_key

        {
          keys: [
            signing_key.slice(:kty, :kid, :e, :n).merge(
              use: 'sig',
              alg: Doorkeeper::OpenidConnect.signing_algorithm
            )
          ]
        }
      end

      def protocol
        if ::Rails.env.production?
          :https
        else
          :http
        end
      end
    end
  end
end
