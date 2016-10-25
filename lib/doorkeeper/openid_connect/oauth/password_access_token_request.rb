module Doorkeeper
  module OpenidConnect
    module OAuth
      module PasswordAccessTokenRequest
        def self.prepended(base)
          base.class_eval do
            attr_reader :nonce
          end
        end

        def initialize(server, client, resource_owner, parameters = {})
          super
          @nonce = parameters[:nonce]
        end

        private

        def after_successful_response
          super
          id_token = Doorkeeper::OpenidConnect::Models::IdToken.new(access_token, nonce)
          @response.id_token = id_token
        end
      end
    end
  end

  OAuth::PasswordAccessTokenRequest.send :prepend, OpenidConnect::OAuth::PasswordAccessTokenRequest
end
