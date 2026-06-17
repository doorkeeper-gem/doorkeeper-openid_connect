# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module GrantTypesSupportedMixin
      def grant_types_supported(doorkeeper)
        grant_types_supported = doorkeeper.grant_flows.dup
        grant_types_supported << "refresh_token" if doorkeeper.refresh_token_enabled?
        grant_types_supported
      end
    end
  end
end
