# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # Shared helpers for building OpenID Connect provider metadata: issuer
    # resolution, `discovery_url_options` handling and namespace-aware endpoint
    # URL resolution. Included by the DiscoveryController and, on
    # Doorkeeper >= 6.0, by MetadataExtension so the RFC 8414 document built by
    # Doorkeeper's own metadata endpoint advertises the same values as the
    # OpenID Connect discovery document.
    module DiscoveryHelpersMixin
      private

      def issuer
        Doorkeeper::OpenidConnect.resolve_issuer(request: request)
      end

      def claims_supported(openid_connect)
        %w[iss sub aud exp iat] | openid_connect.claims.to_h.keys
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
