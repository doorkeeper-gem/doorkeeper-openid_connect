module Doorkeeper
  module OpenidConnect
    module Request
      def get_strategy(grant_or_request_type, available)
        grant_array = grant_or_request_type.split(" ").sort
        if ["id_token", "token"] == grant_array
          Doorkeeper::Request::IdTokenAndToken
        else
          super(grant_or_request_type, available)
        end
      end
    end
  end
  
  Request.send :prepend, OpenidConnect::Request
end
