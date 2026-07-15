# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module GrantTypesSupportedMixin
      def grant_types_supported(doorkeeper)
        grant_types_supported = doorkeeper.grant_flows.dup

        # `use_refresh_token` enables the refresh_token grant without it being
        # listed in `grant_flows`, so it is appended here — but only when it is
        # not already listed explicitly, or it would be advertised twice (the
        # same duplication doorkeeper fixed for its own RFC 8414 metadata in
        # doorkeeper-gem/doorkeeper#1847).
        if doorkeeper.refresh_token_enabled? && !grant_types_supported.include?("refresh_token")
          grant_types_supported << "refresh_token"
        end

        grant_types_supported
      end
    end
  end
end
