module Doorkeeper
  module OpenidConnect
    module Models
      module Claims
        class DistributedClaim < Claim
          attr_accessor :endpoint, :access_token
        end
      end
    end
  end
end