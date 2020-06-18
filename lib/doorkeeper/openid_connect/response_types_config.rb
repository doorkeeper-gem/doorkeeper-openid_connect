# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module ResponseTypeConfig
      private def calculate_authorization_response_types
        types = super
        if grant_flows.include? 'implicit_oidc'
          types << 'token'
          types << 'id_token'
          types << 'id_token token'
        end
        types
      end
    end
  end
end
