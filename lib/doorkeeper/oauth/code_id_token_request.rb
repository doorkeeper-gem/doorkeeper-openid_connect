module Doorkeeper
  module OAuth
    class CodeIdTokenRequest
      attr_accessor :pre_auth, :auth_code, :auth_token, :resource_owner

      def initialize(pre_auth, resource_owner)
        @pre_auth       = pre_auth
        @resource_owner = resource_owner
      end

      def authorize
        if pre_auth.authorizable?
          @auth_code = Authorization::Code.new(pre_auth, resource_owner)
          @auth_token = Authorization::Token.new(pre_auth, resource_owner)
          @auth_code.issue_token
          @auth_token.issue_token
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
        id_token = Doorkeeper::OpenidConnect::CodeIdToken.new(auth_token.token, pre_auth.nonce, auth_code)
        CodeIdTokenResponse.new(pre_auth, auth_code, auth_token, id_token)
      end

      def error_response
        ErrorResponse.from_request pre_auth,
                                   redirect_uri: pre_auth.redirect_uri,
                                   response_on_fragment: true
      end
    end
  end
end
