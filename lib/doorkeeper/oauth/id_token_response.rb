module Doorkeeper
  module OAuth
    class IdTokenResponse < BaseResponse
      include OAuth::Helpers

      attr_accessor :pre_auth, :auth, :response_on_fragment

      def initialize(pre_auth, auth, id_token, options = {})
        @pre_auth = pre_auth
        @auth = auth
        @response_on_fragment = true
        @id_token = id_token
      end

      def redirectable?
        true
      end

      def redirect_uri
        Authorization::URIBuilder.uri_with_fragment(
          pre_auth.redirect_uri,
          access_token: auth.token.token,
          token_type: auth.token.token_type,
          expires_in: auth.token.expires_in_seconds,
          state: pre_auth.state,
          id_token: @id_token.as_jws_token
        )
      end
    end
  end
end
