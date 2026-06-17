# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Rails
      class Routes
        class Mapping
          attr_accessor :controllers, :as, :skips

          def initialize
            @controllers = {
              userinfo: "doorkeeper/openid_connect/userinfo",
              discovery: "doorkeeper/openid_connect/discovery",
              dynamic_client_registration: "doorkeeper/openid_connect/dynamic_client_registration",
            }

            @as = {
              userinfo: :userinfo,
              discovery: :discovery,
              dynamic_client_registration: :dynamic_client_registration,
            }

            @skips = []
          end

          def [](routes)
            {
              controllers: @controllers[routes],
              as: @as[routes],
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
