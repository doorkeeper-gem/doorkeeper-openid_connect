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

          def method_missing(method_sym, *arguments, &block)
            @value
          end

          def response_to?(method_sym, *arguments, &block)
            method_sym.to_s == @name
          end
        end
      end
    end
  end
end