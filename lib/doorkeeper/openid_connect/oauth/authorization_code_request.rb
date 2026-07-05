# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module AuthorizationCodeRequest
        private

        def after_successful_response
          super

          # The nonce was stashed on a one-time OpenidRequest row when the
          # authorization code was issued (see OAuth::Authorization::Code).
          # Read it before destroying the row so it can be bound to the ID
          # Token, then delete the row so a leaked/replayed code cannot mint
          # another token carrying the same nonce.
          openid_request = grant.openid_request
          nonce = openid_request&.nonce
          openid_request&.destroy!

          return unless access_token.includes_scope?("openid")

          id_token = Doorkeeper::OpenidConnect::IdToken.new(access_token, nonce)
          @response.id_token = id_token
        end
      end
    end
  end

  OAuth::AuthorizationCodeRequest.prepend OpenidConnect::OAuth::AuthorizationCodeRequest
end
