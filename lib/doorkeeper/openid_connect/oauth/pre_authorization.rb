# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        # Emit the missing-nonce deprecation at most once per process to avoid
        # spamming logs on every implicit/hybrid authorization request while the
        # `enforce_implicit_nonce` option is still disabled by default.
        @implicit_nonce_deprecation_warned = false

        def self.prepended(base)
          base.validate :nonce, error: Doorkeeper::Errors::InvalidRequest
        end

        def self.warn_missing_nonce_deprecation
          return if @implicit_nonce_deprecation_warned

          @implicit_nonce_deprecation_warned = true
          warn "DEPRECATION WARNING: an OpenID Connect implicit/hybrid flow " \
               "authorization request (a `response_type` including `id_token`) " \
               "was made without a `nonce`. `nonce` is REQUIRED for these flows " \
               "per OpenID Connect Core 1.0 §3.2.2.1. Such requests are currently " \
               "accepted for backward compatibility, but this will change: set " \
               "`enforce_implicit_nonce true` in " \
               "config/initializers/doorkeeper_openid_connect.rb to reject them " \
               "now, as this will become the default in a future major version."
        end

        # Reset the deprecation flag (test helper).
        def self.reset_implicit_nonce_deprecation_warning!
          @implicit_nonce_deprecation_warned = false
        end

        attr_reader :nonce

        def initialize(server, attrs = {}, resource_owner = nil)
          super
          @nonce = attrs[:nonce]
        end

        # NOTE: Auto get default response_mode of specified response_type if response_mode is not
        #   yet present. We can delete this method after Doorkeeper's minimize version support it.
        def response_on_fragment?
          return response_mode == "fragment" if response_mode.present?

          grant_flow = server.authorization_response_flows.detect do |flow|
            flow.matches_response_type?(response_type)
          end

          grant_flow&.default_response_mode == "fragment"
        end

        private

        # Per OpenID Connect Core 1.0 §3.2.2.1, nonce is REQUIRED for the
        # implicit and hybrid flows (any response_type that includes id_token).
        #
        # Enforcement is gated on the `enforce_implicit_nonce` option for
        # backward compatibility: while it is disabled (the current default) a
        # missing nonce is allowed but emits a one-time deprecation warning;
        # once enabled the request is rejected with `invalid_request`.
        def validate_nonce
          return true unless nonce_required_flow?
          return true if nonce.present?

          unless Doorkeeper::OpenidConnect.configuration.enforce_implicit_nonce
            OpenidConnect::OAuth::PreAuthorization.warn_missing_nonce_deprecation
            return true
          end

          @missing_param = :nonce
          false
        end

        # True for the OpenID Connect flows that REQUIRE a nonce: the implicit
        # and hybrid flows, i.e. an `openid`-scoped request whose `response_type`
        # includes `id_token` (per OpenID Connect Core 1.0 §3.2.2.1 and §3.3.2.11).
        def nonce_required_flow?
          scopes.include?("openid") &&
            response_type.to_s.split(" ").include?("id_token")
        end
      end
    end
  end

  OAuth::PreAuthorization.prepend OpenidConnect::OAuth::PreAuthorization
end
