module Doorkeeper
  module OpenidConnect
    module Rails
      class Routes
        class Mapping
          attr_accessor :controllers, :as, :skips

          def initialize
            @controllers = {
              userinfo: 'doorkeeper/openid_connect/userinfo',
              discovery: 'doorkeeper/openid_connect/discovery',
              rp_logout: 'doorkeeper/openid_connect/rp_logout',
            }

            @as = {
              userinfo: :userinfo,
              discovery: :discovery,
              rp_logout: :rp_logout,
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
