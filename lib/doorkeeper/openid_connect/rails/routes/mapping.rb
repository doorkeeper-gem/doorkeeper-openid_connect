# frozen_string_literal: true

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
              authorizations: 'doorkeeper/openid_connect/authorizations'
            }

            @as = {
              userinfo: :userinfo,
              discovery: :discovery,
              authorizations: :authorization
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
