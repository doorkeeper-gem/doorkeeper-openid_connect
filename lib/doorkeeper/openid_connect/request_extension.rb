module Doorkeeper
  module Request
    class << self
      def get_strategy_with_multitype(grant_or_request_type, available)
        grant_array = grant_or_request_type.split(" ").sort
        if ["id_token", "token"] == grant_array
           Doorkeeper::Request::IdTokenAndToken
        else
          get_strategy_without_multitype(grant_or_request_type, available)
        end
      end
      alias_method_chain :get_strategy, :multitype
    end
  end
end
