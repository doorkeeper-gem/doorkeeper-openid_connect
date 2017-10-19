module Doorkeeper
  module OAuth
    class IdTokenRequest
      attr_accessor :pre_auth, :auth, :resource_owner

      def initialize(pre_auth, resource_owner)
        @pre_auth       = pre_auth
        @resource_owner = resource_owner
      end

      def authorize
        if pre_auth.authorizable?
          @auth = Authorization::Token.new(pre_auth, resource_owner)
          @auth.issue_token
          @response = response
        else
          @response = error_response
        end
      end

      def deny
        pre_auth.error = :access_denied
        error_response
      end

      private

      def response
        id_token = Doorkeeper::OpenidConnect::IdToken.new(auth.token, pre_auth.nonce)

        IdTokenResponse.new(pre_auth, auth, id_token)
      end

      def error_response
        ErrorResponse.from_request pre_auth,
                                   redirect_uri: pre_auth.redirect_uri,
                                   response_on_fragment: true
      end
    end
  end
end
