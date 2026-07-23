# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class DiscoveryController < ::Doorkeeper::ApplicationMetalController
      include Doorkeeper::Helpers::Controller
      include GrantTypesSupportedMixin
      include TokenEndpointAuthMethodsSupportedMixin
      include DiscoveryHelpersMixin

      WEBFINGER_RELATION = "http://openid.net/specs/connect/1.0/issuer"

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
          issuer: issuer,
          authorization_endpoint: endpoint_url(:oauth_authorization_url, authorization_url_options),
          token_endpoint: endpoint_url(:oauth_token_url, token_url_options),
          revocation_endpoint: endpoint_url(:oauth_revoke_url, revocation_url_options),
          introspection_endpoint: endpoint_defined?(:oauth_introspect_url) ? endpoint_url(:oauth_introspect_url, introspection_url_options) : nil,
          userinfo_endpoint: endpoint_url(:oauth_userinfo_url, userinfo_url_options),
          jwks_uri: endpoint_url(:oauth_discovery_keys_url, jwks_url_options),
          end_session_endpoint: instance_exec(&openid_connect.end_session_endpoint),
          registration_endpoint: openid_connect.dynamic_client_registration ? endpoint_url(:oauth_dynamic_client_registration_url, dynamic_client_registration_url_options) : nil,

          scopes_supported: doorkeeper.scopes,

          # TODO: support id_token response type
          response_types_supported: doorkeeper.authorization_response_types,
          response_modes_supported: response_modes_supported(doorkeeper),
          grant_types_supported: grant_types_supported(doorkeeper),

          # TODO: look into doorkeeper-jwt_assertion for these
          #  'client_secret_jwt',
          #  'private_key_jwt'
          token_endpoint_auth_methods_supported: token_endpoint_auth_methods_supported,

          # RFC 9207: mirrors Doorkeeper's own RFC 8414 document — true exactly
          # when Doorkeeper is configured with an issuer and therefore emits the
          # `iss` authorization response parameter. `false` survives the
          # `.compact` below, so it is advertised explicitly.
          authorization_response_iss_parameter_supported: Doorkeeper::OpenidConnect.doorkeeper_issuer.present?,

          subject_types_supported: openid_connect.subject_types_supported,

          id_token_signing_alg_values_supported: [
            ::Doorkeeper::OpenidConnect.signing_algorithm,
          ],

          claim_types_supported: [
            "normal",

            # TODO: support these
            # 'aggregated',
            # 'distributed',
          ],

          claims_supported: claims_supported(openid_connect),

          code_challenge_methods_supported: code_challenge_methods_supported(doorkeeper),
        }.compact
      end

      def response_modes_supported(doorkeeper)
        doorkeeper.authorization_response_flows.flat_map(&:response_mode_matches).uniq
      end

      def code_challenge_methods_supported(doorkeeper)
        return unless doorkeeper.access_grant_model.pkce_supported?

        # Doorkeeper < 5.8 has no `pkce_code_challenge_methods` option and
        # always accepts both methods whenever PKCE is available.
        return %w[plain S256] unless doorkeeper.respond_to?(:pkce_code_challenge_methods)

        doorkeeper.pkce_code_challenge_methods
      end

      def webfinger_response
        {
          subject: params.require(:resource),
          links: [
            {
              rel: WEBFINGER_RELATION,
              href: issuer,
            },
          ],
        }
      end

      def keys_response
        { keys: Doorkeeper::OpenidConnect.signing_keys_normalized }
      end
    end
  end
end
