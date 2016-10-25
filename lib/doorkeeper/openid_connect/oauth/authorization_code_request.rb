module Doorkeeper
  module OpenidConnect
    module OAuth
      module AuthorizationCodeRequest
        private

        def after_successful_response
          super
          id_token = Doorkeeper::OpenidConnect::Models::IdToken.new(access_token, grant.openid_connect_nonce.use!)
          @response.id_token = id_token
        end
      end
    end
  end

  OAuth::AuthorizationCodeRequest.send :prepend, OpenidConnect::OAuth::AuthorizationCodeRequest
end
