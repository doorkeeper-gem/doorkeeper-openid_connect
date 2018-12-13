module Doorkeeper
  module OAuth
    class CodeIdTokenTokenRequest < CodeIdTokenRequest
      private

      def response
        id_token_token = Doorkeeper::OpenidConnect::CodeIdTokenToken.new(auth_token.token, pre_auth.nonce, auth_code)

        CodeIdTokenTokenResponse.new(pre_auth, auth_code, auth_token, id_token_token)
      end
    end
  end
end
