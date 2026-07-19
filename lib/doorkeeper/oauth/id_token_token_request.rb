# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class IdTokenTokenRequest < IdTokenRequest
      private

      def response
        token_model = Doorkeeper::OpenidConnect.configuration.id_token_model

        # Only use shipped IdTokenToken if we're using the standard model.
        # This can be cleaned up if/when IdTokenToken goes away.
        if token_model == Doorkeeper::OpenidConnect::IdToken
          id_token_token = Doorkeeper::OpenidConnect::IdTokenToken.new(auth.token, pre_auth.nonce)
        else
          id_token_token = token_model.new(auth.token, pre_auth.nonce)
                                      .extend(Doorkeeper::OpenidConnect::HybridIdTokenConcern)
        end

        IdTokenTokenResponse.new(pre_auth, auth, id_token_token)
      end
    end
  end
end
