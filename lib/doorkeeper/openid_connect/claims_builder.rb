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

      def normal_claim(name, &block)
        @claims[name] =
          Doorkeeper::OpenidConnect::Models::Claims::NormalClaim.new(
            name: name,
            value: block
          )
      end
    end
  end
end
