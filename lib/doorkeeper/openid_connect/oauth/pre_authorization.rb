# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        attr_reader :nonce

        def initialize(server, attrs = {}, resource_owner = nil)
          super
          @nonce = attrs[:nonce]
        end

        # This method will be updated when doorkeeper move to version > 5.2.2
        # TODO: delete this method and refactor response_on_fragment? method (below) when doorkeeper gem version constrains is > 5.2.2
        def error_response
          if error == :invalid_request
            Doorkeeper::OAuth::InvalidRequestResponse.from_request(self, response_on_fragment: response_on_fragment?)
          else
            Doorkeeper::OAuth::ErrorResponse.from_request(self, response_on_fragment: response_on_fragment?)
          end
        end

        def response_on_fragment?
          Doorkeeper::OpenidConnect::ResponseMode.new(response_type).fragment?
        end
      end
    end
  end

  OAuth::PreAuthorization.prepend OpenidConnect::OAuth::PreAuthorization
end
