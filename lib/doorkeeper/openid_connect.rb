# frozen_string_literal: true

require "doorkeeper"
require "active_model"
require "jwt"

# Constants this gem owns that nothing needs while the gem itself loads, wired
# the way `lib/doorkeeper.rb` wires Doorkeeper's own.
#
# The rule for what belongs here: the file defines the constant it is named
# after, and does nothing else. An autoload only ever fires on a reference to
# that one constant, so a file that also defines methods on an already-loaded
# module, or reopens one of Doorkeeper's classes, would have its side effects
# silently skipped — those are required below instead.
#
# This block has to come before the requires: `config.rb` reaches for
# `ClaimsBuilder` while its class body runs.
module Doorkeeper
  module OpenidConnect
    autoload :ClaimsBuilder, "doorkeeper/openid_connect/claims_builder"
    autoload :DiscoveryHelpersMixin, "doorkeeper/openid_connect/discovery_helpers_mixin"
    autoload :Errors, "doorkeeper/openid_connect/errors"
    autoload :GrantTypesSupportedMixin, "doorkeeper/openid_connect/grant_types_supported_mixin"
    autoload :HybridIdTokenConcern, "doorkeeper/openid_connect/hybrid_id_token_concern"
    autoload :IdToken, "doorkeeper/openid_connect/id_token"
    autoload :TokenEndpointAuthMethodsSupportedMixin,
             "doorkeeper/openid_connect/token_endpoint_auth_methods_supported_mixin"
    autoload :UserInfo, "doorkeeper/openid_connect/user_info"
    autoload :VERSION, "doorkeeper/openid_connect/version"

    module Claims
      autoload :Claim, "doorkeeper/openid_connect/claims/claim"
      autoload :NormalClaim, "doorkeeper/openid_connect/claims/normal_claim"
    end

    module OAuth
      autoload :DynamicRegistrationRequest,
               "doorkeeper/openid_connect/oauth/dynamic_registration_request"
    end
  end

  # Requests and responses this gem contributes to Doorkeeper's own namespace.
  # They only add constants — none of them reopens a class Doorkeeper defines —
  # so nothing observes their absence until someone names them, which is what
  # makes them safe to autoload from a namespace this gem does not own.
  #
  # `Request::IdToken` and `Request::IdTokenToken` reach these at request time;
  # for an application that never enables the OpenID Connect implicit or hybrid
  # flows, none of the four is ever loaded.
  module OAuth
    autoload :IdTokenRequest, "doorkeeper/oauth/id_token_request"
    autoload :IdTokenResponse, "doorkeeper/oauth/id_token_response"
    autoload :IdTokenTokenRequest, "doorkeeper/oauth/id_token_token_request"
    autoload :IdTokenTokenResponse, "doorkeeper/oauth/id_token_token_response"
  end
end

require "doorkeeper/request"

# Not autoloadable: the `GrantFlow.register` calls at the bottom of this file
# name both strategy classes while this file loads, so an autoload would fire
# immediately and defer nothing. The requires say that outright.
require "doorkeeper/request/id_token"
require "doorkeeper/request/id_token_token"

# Not autoloadable: besides the `Config` class, `config.rb` defines
# `Doorkeeper::OpenidConnect.configure`, `.configuration` and `.configured?` on
# the module itself. An autoload for `Config` would not fire for any of those,
# leaving `.configure` undefined until something happened to touch `Config`
# first — and calling `.configure` from an initializer is the very first thing
# a host application does.
require "doorkeeper/openid_connect/config"

# Not autoloadable: Rails collects `Rails::Engine` subclasses as they are
# defined, so the engine has to exist by the time the gem finishes loading.
require "doorkeeper/openid_connect/engine"

# Not autoloadable: the file ends by prepending its module onto Doorkeeper's
# own `Helpers::Controller`, and nothing in the gem ever names
# `OpenidConnect::Helpers::Controller` — the controllers reach the behavior
# through Doorkeeper's constant. There would be no reference left to trigger
# the autoload, so the prepend would simply never happen.
require "doorkeeper/openid_connect/helpers/controller"

# Not autoloadable, for the same reason: each of these ends by prepending its
# module onto the Doorkeeper class it extends, and nothing names the module.
require "doorkeeper/openid_connect/oauth/authorization/code"
require "doorkeeper/openid_connect/oauth/authorization_code_request"
require "doorkeeper/openid_connect/oauth/password_access_token_request"
require "doorkeeper/openid_connect/oauth/pre_authorization"
require "doorkeeper/openid_connect/oauth/token_response"

# Defined here rather than in the module body below because the conditional
# declaration that follows already branches on it.
module Doorkeeper
  module OpenidConnect
    # Whether the host Doorkeeper serves its own RFC 8414 Authorization Server
    # Metadata document (Doorkeeper >= 6.0), which this gem enriches with the
    # OpenID Connect metadata instead of serving that path itself.
    #
    # `inherit: false` is load-bearing, not cosmetic. With `const_defined?`'s
    # default the lookup continues into Object, so any top-level
    # `MetadataResponse` in the host application answers for Doorkeeper's —
    # including one that is merely registered as a Zeitwerk autoload, since
    # `const_defined?` is true for a pending autoload. The `::` operator that
    # the callers then use to reach `Doorkeeper::OAuth::MetadataResponse` and
    # `Doorkeeper::MetadataController` does not fall back to Object, so a false
    # positive surfaces as a NameError while this file loads and again in the
    # engine's `to_prepare` block — leaving a Doorkeeper 5.x application unable
    # to boot.
    def self.doorkeeper_metadata_endpoint?
      ::Doorkeeper::OAuth.const_defined?(:MetadataResponse, false)
    end
  end
end

# Doorkeeper >= 6.0 ships an RFC 8414 metadata endpoint; the response subclass
# that enriches it with OIDC metadata only exists when its parent class does.
# The declaration stays behind the version check even though it is now lazy: an
# autoload registered on Doorkeeper 5.x would resolve the moment anything named
# the constant, and fail on the missing superclass instead of never being
# reachable at all.
if Doorkeeper::OpenidConnect.doorkeeper_metadata_endpoint?
  Doorkeeper::OpenidConnect::OAuth.autoload(
    :MetadataResponse,
    "doorkeeper/openid_connect/oauth/metadata_response",
  )
end

# Not autoloadable: the file prepends onto Doorkeeper's access grant mixin as it
# loads, and picks the Doorkeeper 5.5 fallback for that mixin by looking at what
# is already defined — both of which have to happen before the host application
# defines its models. Its own three model constants are autoloaded from there.
require "doorkeeper/openid_connect/orm/active_record"

# Not autoloadable in any useful sense: the engine initializer calls
# `Rails::Routes.install!` on every boot, so the file loads either way, and a
# require is the honest way to write a boot-time dependency.
require "doorkeeper/openid_connect/rails/routes"

module Doorkeeper
  module OpenidConnect
    def self.signing_algorithm
      unwrap_callable(configuration.signing_algorithm).to_s.upcase.to_sym
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
    #
    # Symmetric (`kty: "oct"`) keys are dropped: a JWKS is meant to publish
    # verification keys, but an HMAC JWK *is* the shared secret and cannot
    # serve as a public verification key, so it does not belong in a public
    # discovery document (RFC 7517). HMAC (HS256/HS384/HS512) configurations
    # therefore yield an empty `keys` array here.
    def self.signing_keys_normalized
      alg = signing_algorithm
      exported = signing_keys.map(&:export).reject { |jwk| jwk[:kty] == "oct" }
      exported.map { |jwk| jwk.merge(use: "sig", alg: alg) }
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

    # Returns the issuer configured on Doorkeeper itself, or nil when it is
    # not set, Doorkeeper has not been configured yet, or the installed
    # Doorkeeper version does not expose the option.
    #
    # Doorkeeper added a top-level `issuer` option for RFC 8414 metadata
    # (doorkeeper-gem/doorkeeper#1838) and emits it as the RFC 9207 `iss`
    # authorization response parameter when configured
    # (doorkeeper-gem/doorkeeper#1849). This gem mirrors that gating for the
    # response types and error redirects it owns, so the extension only emits
    # `iss` when Doorkeeper itself does. `resolve_issuer` also falls back to
    # this value when the OpenID Connect `issuer` is not set. `try` returns
    # nil instead of raising on Doorkeeper versions that predate the option.
    #
    # Reading Doorkeeper's config must not force it into existence: before the
    # host application configures Doorkeeper (initializer ordering is its
    # choice), access raises MissingConfiguration on Doorkeeper 5.5 and
    # eagerly builds a default configuration on newer versions, so an
    # unconfigured Doorkeeper reads as "no issuer" instead.
    #
    # TODO: replace `try` with a plain call and bump the gemspec Doorkeeper
    # version constraint once a Doorkeeper release ships `config.issuer`.
    def self.doorkeeper_issuer
      Doorkeeper.config.try(:issuer) if doorkeeper_configured?
    end

    # Whether Doorkeeper has been configured by the host application. Used to
    # decide if Doorkeeper's configuration can be read without side effects:
    # accessing it earlier raises MissingConfiguration on Doorkeeper 5.5 and
    # eagerly builds a default configuration on newer versions. `configured?`
    # itself only exists since Doorkeeper 5.6; 5.5 reports false, which is
    # also correct there — its config has no `issuer` to compare anyway.
    def self.doorkeeper_configured?
      Doorkeeper.respond_to?(:configured?) && Doorkeeper.configured?
    end

    # Resolves the issuer value from the configuration, handling both
    # static values and callable blocks with backward-compatible arity checks.
    #
    # @param resource_owner [Object, nil] the authenticated user (nil in discovery context)
    # @param application [Object, nil] the OAuth application (nil in discovery context)
    # @param request [ActionDispatch::Request, nil] the current request (nil in token context)
    # @return [String] the issuer string
    def self.resolve_issuer(resource_owner: nil, application: nil, request: nil)
      issuer = configuration.issuer

      # Fall back to Doorkeeper's own `issuer` configuration (RFC 8414
      # Authorization Server Metadata) when the OpenID Connect issuer is not
      # set. RFC 8414's `issuer` and the OIDC `iss` claim identify the same
      # authorization server, so a single Doorkeeper-level setting can drive
      # both without duplicate configuration. When neither is configured the
      # existing "issuer not configured" behavior below is preserved.
      issuer = doorkeeper_issuer if issuer.nil?

      value = call_issuer(
        issuer,
        resource_owner: resource_owner,
        application: application,
        request: request,
      ).to_s

      if value.blank?
        raise Errors::InvalidConfiguration,
              I18n.translate("doorkeeper.openid_connect.errors.messages.issuer_not_configured")
      end

      value
    end

    # Resolves the issuer value, dispatching callable issuers with
    # backward-compatible arity checks and returning static values as-is.
    def self.call_issuer(issuer, resource_owner:, application:, request:)
      return issuer unless issuer.respond_to?(:call)

      case issuer.arity
      when 0
        issuer.call
      when 1
        issuer.call(request || resource_owner)
      when 2
        issuer.call(resource_owner, application)
      else
        issuer.call(resource_owner, application, request)
      end
    end
    private_class_method :call_issuer

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
