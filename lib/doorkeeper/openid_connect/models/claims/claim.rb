module Doorkeeper
  module OpenidConnect
    module Models
      module Claims
        class Claim
          attr_accessor :name

          def initialize(options = {})
            @name = options[:name]
          end
        end
      end
    end
  end
end