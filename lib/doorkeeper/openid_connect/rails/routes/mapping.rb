module Doorkeeper
  module OpenidConnect
    module Rails
      class Routes
        class Mapping
          attr_accessor :controllers, :as, :skips

          def initialize
            @controllers = {
              userinfo: 'doorkeeper/openid_connect/userinfo'
            }

            @as = {
              userinfo: :userinfo
            }

            @skips = []
          end

          def [](routes)
            {
              controllers: @controllers[routes],
              as: @as[routes]
            }
          end

          def skipped?(controller)
            @skips.include?(controller)
          end
        end
      end
    end
  end
end
