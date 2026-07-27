# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class DiscoveryController < ::Doorkeeper::ApplicationMetalController
      include Doorkeeper::Helpers::Controller
      include GrantTypesSupportedMixin
      include TokenEndpointAuthMethodsSupportedMixin

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

      def claims_supported(openid_connect)
        %w[iss sub aud exp iat] | openid_connect.claims.to_h.keys
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

      def protocol
        configured = Doorkeeper::OpenidConnect.configuration.protocol
        configured.respond_to?(:call) ? configured.call : configured
      end

      def discovery_url_options
        Doorkeeper::OpenidConnect.configuration.discovery_url_options.call(request)
      end

      def discovery_url_default_options
        { protocol: protocol }
      end

      def issuer
        Doorkeeper::OpenidConnect.resolve_issuer(request: request)
      end

      # Resolves a Doorkeeper URL helper, honouring the namespace under which the
      # engine is mounted. When mounted under a named scope (e.g.
      # `scope :users, as: :users`), the route helpers are prefixed
      # (`users_oauth_authorization_url`); the prefix is supplied as a route
      # default by `use_doorkeeper_openid_connect as: :users`. With no namespace
      # the prefix is empty and the bare helper (`oauth_authorization_url`) is
      # used, preserving the single-mount behaviour.
      def endpoint_url(helper, options = {})
        public_send(:"#{route_helper_prefix}#{helper}", options)
      end

      def endpoint_defined?(helper)
        respond_to?(:"#{route_helper_prefix}#{helper}")
      end

      def route_helper_prefix
        request.path_parameters[:route_helper_prefix].to_s
      end

      %i[authorization token revocation introspection userinfo jwks
         dynamic_client_registration].each do |endpoint|
        define_method :"#{endpoint}_url_options" do
          discovery_url_default_options.merge(discovery_url_options[endpoint.to_sym] || {})
        end
      end
    end
  end
end
