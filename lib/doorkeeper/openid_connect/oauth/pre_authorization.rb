module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        attr_reader :nonce

        def initialize(server, client, attrs = {})
          super
          @nonce = attrs[:nonce]
        end
      end
    end
  end

  OAuth::PreAuthorization.send :prepend, OpenidConnect::OAuth::PreAuthorization
end
