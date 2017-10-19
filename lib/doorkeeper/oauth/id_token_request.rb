module Doorkeeper
  module OAuth
    class IdTokenRequest
      attr_accessor :pre_auth, :resource_owner

      def initialize(pre_auth, resource_owner)
        @pre_auth       = pre_auth
        @resource_owner = resource_owner
      end

      def authorize
        if pre_auth.authorizable?
          auth = Authorization::Token.new(pre_auth, resource_owner)
          auth.issue_token
          id_token = Doorkeeper::OpenidConnect::IdToken.new(auth.token, pre_auth.nonce, response_type: pre_auth.response_type)
          @response = IdTokenResponse.new pre_auth, auth, id_token
        else
          @response = error_response
        end
      end

      def deny
        pre_auth.error = :access_denied
        error_response
      end

      private

      def error_response
        ErrorResponse.from_request pre_auth,
                                   redirect_uri: pre_auth.redirect_uri,
                                   response_on_fragment: true
      end
    end
  end
end
