module Doorkeeper
  module OpenidConnect
    module ResponseTypeConfig
      private def calculate_authorization_response_types
        types = super
        if grant_flows.include? 'implicit_oidc'
          types << 'id_token token'
          types << 'token'
        end
        types
      end
    end
  end

  Config.send :prepend, OpenidConnect::ResponseTypeConfig
end
