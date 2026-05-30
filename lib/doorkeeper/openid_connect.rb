# frozen_string_literal: true

require "doorkeeper"
require "active_model"
require "jwt"

require "doorkeeper/request"
require "doorkeeper/request/id_token"
require "doorkeeper/request/id_token_token"
require "doorkeeper/oauth/id_token_request"
require "doorkeeper/oauth/id_token_token_request"
require "doorkeeper/oauth/id_token_response"
require "doorkeeper/oauth/id_token_token_response"

require "doorkeeper/openid_connect/claims_builder"
require "doorkeeper/openid_connect/claims/claim"
require "doorkeeper/openid_connect/claims/normal_claim"
require "doorkeeper/openid_connect/config"
require "doorkeeper/openid_connect/engine"
require "doorkeeper/openid_connect/errors"
require "doorkeeper/openid_connect/id_token"
require "doorkeeper/openid_connect/id_token_token"
require "doorkeeper/openid_connect/user_info"
require "doorkeeper/openid_connect/version"

require "doorkeeper/openid_connect/helpers/controller"

require "doorkeeper/openid_connect/grant_types_supported_mixin"
require "doorkeeper/openid_connect/token_endpoint_auth_methods_supported_mixin"

require "doorkeeper/openid_connect/oauth/authorization/code"
require "doorkeeper/openid_connect/oauth/authorization_code_request"
require "doorkeeper/openid_connect/oauth/dynamic_registration_request"
require "doorkeeper/openid_connect/oauth/password_access_token_request"
require "doorkeeper/openid_connect/oauth/pre_authorization"
require "doorkeeper/openid_connect/oauth/token_response"

require "doorkeeper/openid_connect/orm/active_record"

require "doorkeeper/openid_connect/rails/routes"

module Doorkeeper
  module OpenidConnect
    def self.signing_algorithm
      algo = if configuration.signing_algorithm.respond_to?(:call)
               configuration.signing_algorithm.call
             else
               configuration.signing_algorithm
             end
      algo.to_s.upcase.to_sym
    end

    # Returns the active signing key used when issuing new ID tokens.
    # When multiple keys are configured (see `.signing_keys`), this is the
    # first entry; the remaining keys are exposed via the JWKS endpoint so
    # clients can still validate tokens signed with retired keys during a
    # rotation window.
    def self.signing_key
      build_jwk(normalize_entry(resolved_signing_entries.first))
    end

    # Returns every configured key as a `JWT::JWK` instance, in the order
    # they were declared. The first entry is the active signing key; the
    # rest are kept for JWKS publication only (e.g. during key rotation).
    def self.signing_keys
      resolved_signing_entries.map { |entry| build_jwk(normalize_entry(entry)) }
    end

    def self.signing_key_normalized
      signing_key.export
    end

    # Returns every configured key formatted for inclusion in the JWKS
    # response, with `use` and `alg` already merged. The discovery
    # controller renders this verbatim inside `keys: [...]`.
    def self.signing_keys_normalized
      alg = signing_algorithm
      signing_keys.map { |jwk| jwk.export.merge(use: "sig", alg: alg) }
    end

    def self.unwrap_callable(value)
      value.respond_to?(:call) ? value.call : value
    end
    private_class_method :unwrap_callable

    # Resolves `configuration.signing_key` into the raw entry array, ahead
    # of any per-entry normalization or JWK construction. Sharing this
    # between `.signing_key` and `.signing_keys` keeps the empty-array
    # guard in one place and lets `.signing_key` build only the active
    # entry, avoiding redundant `OpenSSL::PKey.read` work on the ID token
    # signing hot path when multiple keys are configured.
    def self.resolved_signing_entries
      raw = unwrap_callable(configuration.signing_key)
      entries = Array.wrap(raw).compact
      if entries.empty?
        raise Errors::InvalidConfiguration,
              I18n.translate("doorkeeper.openid_connect.errors.messages.signing_key_not_configured")
      end
      entries
    end
    private_class_method :resolved_signing_entries

    # Normalizes a single entry of the `signing_key` configuration into a
    # canonical Hash. Today the only recognized shape is the bare key value
    # (a PEM string for asymmetric algorithms or a shared secret for HMAC),
    # but this indirection lets future PRs introduce per-key options
    # (e.g. `{ key:, algorithm:, kid:, use: }`) without touching the
    # discovery controller or the JWKS rendering path.
    def self.normalize_entry(entry)
      entry.is_a?(Hash) ? entry : { key: entry }
    end
    private_class_method :normalize_entry

    def self.build_jwk(entry)
      key_value = entry.fetch(:key)
      key =
        if %i[HS256 HS384 HS512].include?(signing_algorithm)
          key_value
        else
          OpenSSL::PKey.read(key_value)
        end
      ::JWT::JWK.new(key, { kid_generator: ::JWT::JWK::Thumbprint })
    end
    private_class_method :build_jwk

    # Resolves the issuer value from the configuration, handling both
    # static values and callable blocks with backward-compatible arity checks.
    #
    # @param resource_owner [Object, nil] the authenticated user (nil in discovery context)
    # @param application [Object, nil] the OAuth application (nil in discovery context)
    # @param request [ActionDispatch::Request, nil] the current request (nil in token context)
    # @return [String] the issuer string
    def self.resolve_issuer(resource_owner: nil, application: nil, request: nil)
      issuer = configuration.issuer
      return issuer.to_s unless issuer.respond_to?(:call)

      case issuer.arity
      when 0
        issuer.call
      when 1
        issuer.call(request || resource_owner)
      when 2
        issuer.call(resource_owner, application)
      else
        issuer.call(resource_owner, application, request)
      end.to_s
    end

    Doorkeeper::GrantFlow.register(
      :id_token,
      response_type_matches: "id_token",
      response_mode_matches: %w[fragment form_post],
      response_type_strategy: Doorkeeper::Request::IdToken,
    )

    Doorkeeper::GrantFlow.register(
      "id_token token",
      response_type_matches: "id_token token",
      response_mode_matches: %w[fragment form_post],
      response_type_strategy: Doorkeeper::Request::IdTokenToken,
    )

    Doorkeeper::GrantFlow.register_alias(
      "implicit_oidc", as: ["implicit", "id_token", "id_token token"],
    )
  end
end
