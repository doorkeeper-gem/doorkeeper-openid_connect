# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module PasswordAccessTokenRequest
        attr_reader :nonce

        # Forward every argument: the superclass signature has changed across
        # Doorkeeper versions and keeps changing (e.g. doorkeeper#1794).
        def initialize(...)
          super
          @nonce = parameters[:nonce]
        end

        private

        def after_successful_response
          if access_token.includes_scope?("openid")
            id_token = Doorkeeper::OpenidConnect.configuration.id_token_model
                                                .new(access_token, nonce)
            @response.id_token = id_token
          end
          super
        end
      end
    end
  end

  OAuth::PasswordAccessTokenRequest.prepend OpenidConnect::OAuth::PasswordAccessTokenRequest
end
