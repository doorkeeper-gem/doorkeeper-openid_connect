# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module TokenEndpointAuthMethodsSupportedMixin
      # Maps Doorkeeper's legacy +client_credentials+ method identifiers to the
      # RFC 8414 +token_endpoint_auth_methods_supported+ names. Only used on
      # Doorkeeper versions that predate the client authentication methods
      # registry (doorkeeper-gem/doorkeeper#1840); newer versions expose the
      # RFC 8414 names directly via +client_authentication_methods+.
      CLIENT_CREDENTIALS_METHOD_MAPPING = {
        from_basic: "client_secret_basic",
        from_params: "client_secret_post",
      }.freeze

      # The "none" pseudo-method (public clients, RFC 8414) is not a token
      # endpoint authentication method advertised by the discovery metadata,
      # and the dynamic client registration request appends it separately when
      # validating public clients (see +PUBLIC_CLIENT_AUTH_METHOD+). The legacy
      # mapping never produced it; the new registry includes it in the default
      # +client_authentication+ set, so it is filtered out here to keep the
      # advertised methods identical across both code paths.
      PUBLIC_CLIENT_AUTH_METHOD_NAME = "none"

      def token_endpoint_auth_methods_supported
        config = doorkeeper_config

        # Doorkeeper >= the release shipping the client authentication methods
        # registry (doorkeeper-gem/doorkeeper#1840) exposes
        # +client_authentication_methods+, returning
        # +Doorkeeper::ClientAuthentication::Method+ objects whose +name+ is
        # already the RFC 8414 identifier (e.g. :client_secret_basic), so no
        # translation is needed. Older versions only expose
        # +client_credentials_methods+, returning bare strategy symbols
        # (:from_basic / :from_params) that the mapping above translates.
        #
        # TODO: once a Doorkeeper release ships +client_authentication_methods+,
        # bump the gemspec Doorkeeper version constraint and remove the
        # +respond_to?+ guard, the legacy +else+ branch, and the
        # +CLIENT_CREDENTIALS_METHOD_MAPPING+ constant.
        names =
          if config.respond_to?(:client_authentication_methods)
            config.client_authentication_methods.map { |method| method.name.to_s }
          else
            config.client_credentials_methods.filter_map do |method|
              CLIENT_CREDENTIALS_METHOD_MAPPING[method]
            end
          end

        names.reject { |name| name == PUBLIC_CLIENT_AUTH_METHOD_NAME }
      end

      private

      # Indirection over +Doorkeeper.config+ so specs can supply a stand-in
      # configuration (the registry API only exists on unreleased Doorkeeper)
      # without replacing +Doorkeeper.config+ wholesale, which would otherwise
      # leak into the per-example configuration reload.
      def doorkeeper_config
        ::Doorkeeper.config
      end
    end
  end
end
