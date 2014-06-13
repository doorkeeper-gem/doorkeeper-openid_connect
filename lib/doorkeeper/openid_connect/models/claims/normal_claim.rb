module Doorkeeper
  module OpenidConnect
    module Models
      module Claims
        class NormalClaim < Claim
          attr_accessor :value

          def type
            :normal
          end
        end
      end
    end
  end
end