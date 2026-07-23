# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # Prepended to Doorkeeper::MetadataController (Doorkeeper >= 6.0) so the
    # RFC 8414 document at `/.well-known/oauth-authorization-server` also
    # carries the OpenID Connect metadata this gem serves from its discovery
    # document — otherwise the two documents describe the same server with a
    # different issuer and without the OIDC endpoints and capabilities.
    #
    # When mounted under a named scope, Doorkeeper's metadata route carries no
    # `route_helper_prefix`, so the enriched endpoints resolve to the default
    # mount — matching how the core document advertises its own endpoints
    # there. Scoped mounts are fully served by the gem's namespaced
    # `/.well-known/openid-configuration` document.
    module MetadataExtension
      include DiscoveryHelpersMixin

      private

      def metadata_response
        return super unless Doorkeeper::OpenidConnect.configured? && oidc_routes_mounted?

        @metadata_response ||= Doorkeeper::OpenidConnect::OAuth::MetadataResponse.new(
          request.base_url,
          ->(**args) { url_for(**args) },
          issuer: issuer,
          oidc_metadata: oidc_metadata,
        )
      end

      # This controller is reachable through Doorkeeper's own routes, so it
      # also serves apps that configure this gem without mounting
      # `use_doorkeeper_openid_connect` (or that skip routes through its
      # mapping) — where the gem's URL helpers are not defined. Rather than
      # raise, or advertise an OIDC document missing its core endpoints, fall
      # back to the plain Doorkeeper document.
      def oidc_routes_mounted?
        endpoint_defined?(:oauth_userinfo_url) &&
          endpoint_defined?(:oauth_discovery_keys_url)
      end

      def oidc_metadata
        openid_connect = Doorkeeper::OpenidConnect.configuration

        {
          userinfo_endpoint: endpoint_url(:oauth_userinfo_url, userinfo_url_options),
          jwks_uri: endpoint_url(:oauth_discovery_keys_url, jwks_url_options),
          end_session_endpoint: instance_exec(&openid_connect.end_session_endpoint),
          registration_endpoint: registration_endpoint_url(openid_connect),
          subject_types_supported: openid_connect.subject_types_supported,
          id_token_signing_alg_values_supported: [::Doorkeeper::OpenidConnect.signing_algorithm],
          claim_types_supported: ["normal"],
          claims_supported: claims_supported(openid_connect),
        }.compact
      end

      def registration_endpoint_url(openid_connect)
        return unless openid_connect.dynamic_client_registration
        # The registration route is drawn conditionally on the configuration
        # at the time the app's routes were loaded, so it can be absent even
        # while `dynamic_client_registration` is enabled.
        return unless endpoint_defined?(:oauth_dynamic_client_registration_url)

        endpoint_url(
          :oauth_dynamic_client_registration_url,
          dynamic_client_registration_url_options,
        )
      end
    end
  end
end
