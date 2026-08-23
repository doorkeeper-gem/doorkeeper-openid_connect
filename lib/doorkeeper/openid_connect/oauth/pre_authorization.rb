# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        # Emit the missing-nonce deprecation at most once per process to avoid
        # spamming logs on every Implicit Flow authorization request while the
        # `enforce_implicit_nonce` option is still disabled by default.
        @implicit_nonce_deprecation_warned = false

        def self.prepended(base)
          base.validate :nonce, error: invalid_request_error(base)
        end

        # Doorkeeper's `PreAuthorization#error_response` recognises a failed
        # validation by comparing the recorded error against whatever its own
        # validations registered, and that representation changed mid-series:
        # 5.5.x through 5.6.7 register symbols (`:invalid_request`), 5.6.8 and
        # later register error classes (`Doorkeeper::Errors::InvalidRequest`).
        # Testing for the constant is not enough to tell them apart — 5.6.7
        # defines `Errors::InvalidRequest` while still registering symbols, so a
        # nonce rejection there would carry a value `error_response` does not
        # recognise, skip the dedicated `InvalidRequestResponse`, and emit the
        # class in place of `invalid_request`. Mirror whatever Doorkeeper
        # registered for its own `params` validation instead, which is an
        # invalid-request error in every supported version and therefore always
        # in the representation that version compares against.
        def self.invalid_request_error(base = ::Doorkeeper::OAuth::PreAuthorization)
          base.validations.find { |validation| validation[:attribute] == :params }
              &.dig(:options, :error) || :invalid_request
        end

        def self.warn_missing_nonce_deprecation
          return if @implicit_nonce_deprecation_warned

          @implicit_nonce_deprecation_warned = true
          warn "DEPRECATION WARNING: an OpenID Connect Implicit Flow " \
               "authorization request (a `response_type` of `id_token` or " \
               "`id_token token`) was made without a `nonce`. `nonce` is REQUIRED " \
               "for this flow per OpenID Connect Core 1.0 §3.2.2.1. Such requests " \
               "are currently accepted for backward compatibility, but this " \
               "will change: set `enforce_implicit_nonce true` in " \
               "config/initializers/doorkeeper_openid_connect.rb to reject them " \
               "now, as this will become the default in the major version after "\
               "the one that introduces this option."
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

        # Carry the nonce through the `api_only` consent step as well. There the
        # authorization form is not rendered at all: Doorkeeper answers with
        # `render json: pre_auth`, and so does this gem for `prompt=consent`, so
        # the bundled view cannot relay anything. A host application that
        # rebuilds the approve request from this payload would drop the nonce
        # exactly the way the HTML form did before the view was bundled.
        #
        # The key is omitted entirely when there is no nonce, so a plain OAuth
        # pre-authorization keeps the payload Doorkeeper already documents.
        def as_json(options = nil)
          json = super
          return json if nonce.blank?

          json.merge(nonce: nonce)
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

        # Per OpenID Connect Core 1.0 §3.2.2.1, nonce is REQUIRED for the Implicit
        # Flow, i.e. any response_type that includes id_token.
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

        # True for the OpenID Connect flow that REQUIRES a nonce: the Implicit
        # Flow, i.e. an `openid`-scoped request whose `response_type` includes
        # `id_token` (per OpenID Connect Core 1.0 §3.2.2.1).
        def nonce_required_flow?
          scopes.include?("openid") &&
            response_type.to_s.split(" ").include?("id_token")
        end
      end
    end
  end

  OAuth::PreAuthorization.prepend OpenidConnect::OAuth::PreAuthorization
end
