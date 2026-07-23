# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      # OpenID Connect flavour of Doorkeeper's RFC 8414 Authorization Server
      # Metadata response (Doorkeeper >= 6.0). The OIDC fields are injected
      # through the `custom_metadata` seam the core response merges last, so
      # precedence is: Doorkeeper defaults < OIDC metadata < app-configured
      # `custom_metadata`.
      class MetadataResponse < ::Doorkeeper::OAuth::MetadataResponse
        def initialize(base_url, url_builder, issuer:, oidc_metadata:)
          super(base_url, url_builder)
          @oidc_issuer = issuer
          @oidc_metadata = oidc_metadata
        end

        private

        # The resolved OpenID Connect issuer (which itself falls back to
        # Doorkeeper's `issuer`), so this document, the OIDC discovery document
        # and the `iss` ID token claim all name the same authorization server.
        def issuer
          @oidc_issuer
        end

        def custom_metadata
          @oidc_metadata.merge(super)
        end
      end
    end
  end
end
