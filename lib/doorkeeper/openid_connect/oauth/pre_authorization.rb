module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        def self.prepended(base)
          base.class_eval do
            attr_reader :nonce
          end
        end

        def initialize(server, client, attrs = {})
          super
          @nonce = attrs[:nonce]
        end
      end
    end
  end

  OAuth::PreAuthorization.send :prepend, OpenidConnect::OAuth::PreAuthorization
end
