require 'ostruct'

module Doorkeeper
  module OpenidConnect
    class ClaimsBuilder
      def initialize(&block)
        @claims = OpenStruct.new
        instance_eval(&block)
      end

      def build
        @claims
      end

      def normal_claim(name, scope: nil, &block)
        @claims[name] =
          Claims::NormalClaim.new(
            name: name,
            scope: scope,
            generator: block
          )
      end
      alias_method :claim, :normal_claim
    end
  end
end
