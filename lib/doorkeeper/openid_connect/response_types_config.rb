module Doorkeeper
  module OpenidConnect
    module ResponseTypeConfig
      private def calculate_authorization_response_types
        types = super
        if grant_flows.include? 'implicit_oidc'
          types << 'token id_token' # As per OpenID specification
          types << 'id_token token' # But we can support either order
          types << 'token'
        end
        types
      end
    end
  end

  Config.send :prepend, OpenidConnect::ResponseTypeConfig
end
