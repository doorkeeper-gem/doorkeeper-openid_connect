module Doorkeeper
  module OAuth
    class IdTokenTokenResponse < IdTokenResponse
      private

      def redirect_uri_params
        super.merge({
          access_token: auth.token.token,
          token_type: auth.token.token_type
        })
      end
    end
  end
end
