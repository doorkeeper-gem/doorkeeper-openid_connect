# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module GrantTypesSupportedMixin
      # `implicit_oidc` is the internal grant flow this gem registers to add
      # the `id_token` / `id_token token` response types on top of
      # Doorkeeper's `implicit` flow. Externally (RFC 7591 §2 / OIDC
      # Discovery `grant_types_supported`) the registered grant type name is
      # `implicit` — the internal flow name must not leak into responses.
      INTERNAL_GRANT_TYPE_MAPPING = {
        "implicit_oidc" => "implicit",
      }.freeze

      def grant_types_supported(doorkeeper)
        # `uniq` also covers a configuration listing both `implicit` and
        # `implicit_oidc`, which map to the same external grant type.
        grant_types_supported = doorkeeper.grant_flows.map do |flow|
          INTERNAL_GRANT_TYPE_MAPPING.fetch(flow, flow)
        end.uniq

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
