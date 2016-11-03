module Doorkeeper
  module OpenidConnect
    module OAuth
      module TokenResponse
        attr_accessor :id_token

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
