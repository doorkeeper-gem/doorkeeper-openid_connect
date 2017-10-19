module Doorkeeper
  module OpenidConnect
    module ResponseTypeConfig
      private def calculate_authorization_response_types
        types = super
        types << ['id_token', 'token'] if grant_flows.include? 'implicit_oidc'
        types << ['id_token'] if grant_flows.include? 'implicit_oidc'
        types
      end
    end
  end

  Config.send :prepend, OpenidConnect::ResponseTypeConfig
end
