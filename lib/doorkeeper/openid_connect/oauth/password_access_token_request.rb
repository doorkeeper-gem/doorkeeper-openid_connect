# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module PasswordAccessTokenRequest
        attr_reader :nonce

        def initialize(server, client, credentials, resource_owner, parameters = {})
          super
          @nonce = parameters[:nonce]
        end

        private

        def after_successful_response
          id_token = Doorkeeper::OpenidConnect::IdToken.new(access_token, nonce)
          @response.id_token = id_token
          super
        end
      end
    end
  end

  OAuth::PasswordAccessTokenRequest.prepend OpenidConnect::OAuth::PasswordAccessTokenRequest
end
