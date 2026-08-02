# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class IdTokenTokenResponse < IdTokenResponse
      def body
        super.merge({
          # `plaintext_token`, not `token`: with a hashing token-secret
          # strategy the stored `token` attribute is the hash, so returning it
          # would hand the client an unusable access token (mirrors core
          # `CodeResponse` / `TokenResponse`, which return `plaintext_token`).
          access_token: auth.token.plaintext_token,
          token_type: auth.token.token_type,
          expires_in: auth.token.expires_in_seconds,
        })
      end
    end
  end
end
