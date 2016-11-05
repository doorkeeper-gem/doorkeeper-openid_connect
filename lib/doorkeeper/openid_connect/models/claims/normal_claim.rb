module Doorkeeper
  module OpenidConnect
    module Models
      module Claims
        class NormalClaim < Claim
          attr_reader :value

          def initialize(options = {})
            super(options)
            @value = options[:value]
          end

          def type
            :normal
          end

          def to_proc
            @value
          end
        end
      end
    end
  end
end
