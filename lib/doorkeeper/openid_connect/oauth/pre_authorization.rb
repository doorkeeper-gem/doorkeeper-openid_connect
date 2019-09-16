module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        attr_reader :nonce

        def initialize(server, client_or_attrs, attrs = {})
          if client_or_attrs.is_a?(ActionController::Parameters)
            attrs = client_or_attrs
            client = nil
          else
            client = client_or_attrs
          end

          if OAuth::PreAuthorization.method(:initialize).parameters.include?([:req, :client])
            super(server, client, attrs)
          else
            super(server, attrs)
          end
          @nonce = attrs[:nonce]
        end
      end
    end
  end

  OAuth::PreAuthorization.send :prepend, OpenidConnect::OAuth::PreAuthorization
end
