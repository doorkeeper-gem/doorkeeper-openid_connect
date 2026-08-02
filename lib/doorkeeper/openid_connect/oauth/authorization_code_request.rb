# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module AuthorizationCodeRequest
        private

        def after_successful_response
          # The nonce was stashed on a one-time OpenidRequest row when the
          # authorization code was issued (see OAuth::Authorization::Code).
          # Read it before destroying the row so it can be bound to the ID
          # Token, then delete the row so a leaked/replayed code cannot mint
          # another token carrying the same nonce.
          openid_request = grant.openid_request
          nonce = openid_request&.nonce
          openid_request&.destroy!

          if access_token.includes_scope?("openid")
            id_token = Doorkeeper::OpenidConnect.configuration.id_token_model
                                                .new(access_token, nonce)
            @response.id_token = id_token
          end

          # Attach the ID token to the response *before* calling super, which
          # fires `after_successful_strategy_response`. This matches
          # PasswordAccessTokenRequest so a consumer's hook sees the complete
          # token response (including `id_token`) in both flows.
          super
        end
      end
    end
  end

  OAuth::AuthorizationCodeRequest.prepend OpenidConnect::OAuth::AuthorizationCodeRequest
end
