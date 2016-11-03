module Doorkeeper
  module OpenidConnect
    module OAuth
      module TokenResponse
        def self.prepended(base)
          base.class_eval do
            attr_accessor :id_token
          end
        end

        def body
          if token.includes_scope? 'openid'
            super.
              merge({:id_token => id_token.try(:as_jws_token)}).
              reject { |_, value| value.blank? }
          else
            super
          end
        end
      end
    end
  end

  OAuth::TokenResponse.send :prepend, OpenidConnect::OAuth::TokenResponse
end
