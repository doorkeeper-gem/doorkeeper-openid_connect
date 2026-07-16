# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module AuthorizationsExtension
      private

      # Whitelist the OIDC `nonce` authorization parameter so Doorkeeper
      # carries it into the PreAuthorization (see
      # Doorkeeper::OpenidConnect::OAuth::PreAuthorization#initialize, which
      # reads `attrs[:nonce]`). Without this the nonce would be dropped and
      # never make it onto the issued ID Token.
      def pre_auth_param_fields
        super.append(:nonce)
      end
    end
  end
end
