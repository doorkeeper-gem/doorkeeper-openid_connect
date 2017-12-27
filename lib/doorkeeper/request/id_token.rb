require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class IdToken < Strategy
      delegate :current_resource_owner, to: :server

      def pre_auth
        server.context.send(:pre_auth)
      end

      def request
        @request ||= OAuth::IdTokenRequest.new(pre_auth, current_resource_owner)
      end
    end
  end
end
