module Doorkeeper
  module OAuth
    class IdTokenTokenResponse < IdTokenResponse
      def redirect_uri
        Authorization::URIBuilder.uri_with_fragment(pre_auth.redirect_uri, redirect_uri_params)
      end

      private

      def redirect_uri_params
        {
          access_token: auth.token.token,
          token_type: auth.token.token_type,
          expires_in: auth.token.expires_in_seconds,
          state: pre_auth.state,
          id_token: id_token.as_jws_token
        }
      end
    end
  end
end
