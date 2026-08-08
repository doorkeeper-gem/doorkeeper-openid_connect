# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    def self.configure(&block)
      if Doorkeeper.configuration.orm != :active_record
        raise Errors::InvalidConfiguration,
              "Doorkeeper OpenID Connect currently only supports the ActiveRecord ORM adapter"
      end

      @config = Config::Builder.new(&block).build
      validate_issuer_consistency
      @config
    end

    def self.configuration
      @config || (raise Errors::MissingConfiguration)
    end

    # Whether `Doorkeeper::OpenidConnect.configure` has been run. Guards
    # integrations that must fall back to plain Doorkeeper behaviour (e.g. the
    # RFC 8414 metadata enrichment) when the app loads this gem without
    # configuring it.
    def self.configured?
      !@config.nil?
    end

    # Warn when Doorkeeper's `issuer` and the OpenID Connect `issuer` are both
    # statically configured with different values. Clients validate the
    # RFC 9207 `iss` authorization response parameter (emitted by Doorkeeper
    # from its own `issuer`) against the issuer they discovered — for OIDC
    # clients that is this gem's discovery document, which serves the OpenID
    # Connect `issuer`. Diverging values make conforming clients reject every
    # authorization response, so surface the misconfiguration at boot. Callable
    # OpenID Connect issuers cannot be compared statically and are skipped.
    def self.validate_issuer_consistency
      oidc_issuer = @config.issuer
      return if oidc_issuer.respond_to?(:call)

      # `doorkeeper_issuer` reads as nil while Doorkeeper is not yet
      # configured (initializer ordering is the host app's choice), so the
      # check silently passes in that case instead of forcing Doorkeeper's
      # config into existence.
      doorkeeper_issuer_value = doorkeeper_issuer
      return if oidc_issuer.blank? || doorkeeper_issuer_value.blank?
      return if oidc_issuer.to_s == doorkeeper_issuer_value.to_s

      ::Rails.logger.warn(
        "[DOORKEEPER-OPENID_CONNECT] The configured OpenID Connect issuer " \
          "(#{oidc_issuer.to_s.inspect}) differs from Doorkeeper's issuer " \
          "(#{doorkeeper_issuer_value.to_s.inspect}). The discovery document advertises " \
          "the former while Doorkeeper's RFC 8414 metadata and RFC 9207 iss " \
          "parameter use the latter; RFC 9207-conforming clients compare the " \
          "two and will reject authorization responses. Configure a single " \
          "issuer value.",
      )
    end

    private_class_method :validate_issuer_consistency

    class Config
      class Builder
        def initialize(&block)
          @config = Config.new
          instance_eval(&block)
        end

        def build
          @config
        end
      end

      mattr_reader(:builder_class) { Config::Builder }

      extend ::Doorkeeper::Config::Option

      option :issuer
      option :signing_key
      option :signing_algorithm, default: :rs256
      option :subject_types_supported, default: [:public]

      option :resource_owner_from_access_token, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate("doorkeeper.openid_connect.errors.messages.resource_owner_from_access_token_not_configured")
      }

      option :auth_time_from_resource_owner, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate("doorkeeper.openid_connect.errors.messages.auth_time_from_resource_owner_not_configured")
      }

      option :auth_time_from_session, default: nil
      option :auth_time_from_access_token, default: nil

      option :reauthenticate_resource_owner, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate("doorkeeper.openid_connect.errors.messages.reauthenticate_resource_owner_not_configured")
      }

      option :select_account_for_resource_owner, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate("doorkeeper.openid_connect.errors.messages.select_account_for_resource_owner_not_configured")
      }

      option :subject, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate("doorkeeper.openid_connect.errors.messages.subject_not_configured")
      }

      option :expiration, default: 120

      option :claims, builder_class: ClaimsBuilder

      option :protocol, default: lambda { |*_|
        ::Rails.env.production? ? :https : :http
      }

      option :end_session_endpoint, default: lambda { |*_|
        nil
      }

      option :discovery_url_options, default: lambda { |*_|
        {}
      }

      option :dynamic_client_registration, default: false

      # When enabled, the `prompt` authorization parameter (`none`, `login`,
      # `consent`, `select_account`) is honored even on non-OIDC requests,
      # i.e. when the `openid` scope is not part of the authorization request.
      # `max_age` remains OIDC-only because it is defined by OIDC Core.
      option :apply_prompt_to_non_oidc_requests, default: false

      option :authorize_dynamic_client_registration, default: nil

      option :open_id_request_class, default: "Doorkeeper::OpenidConnect::Request"

      # A class that provides custom behavior for generating ID tokens.
      # Must inherit from `Doorkeeper::OpenidConnect::IdToken`, which carries the
      # security-critical invariants (required-claim enforcement, the merge order that keeps the
      # `claims` configuration block from overriding `sub`/`aud`/`exp`, nonce and `at_hash`
      # handling), so a subclass only overrides what it actually needs — typically `claims`
      # (call `super.merge(...)` so the registered claims are always present; a key you add that
      # collides with one of them does replace it, so keep your keys distinct unless replacing it
      # is what you mean), `audience`, or `select_key` for custom signing-key selection.
      option :id_token_class, default: "Doorkeeper::OpenidConnect::IdToken"

      # A class that provides custom behavior for generating the UserInfo response.
      # Must inherit from `Doorkeeper::OpenidConnect::UserInfo`; a subclass typically only
      # overrides `claims` (call `super.merge(...)`, and leave `sub` out of the merged hash unless
      # replacing the canonical subject identifier is what you mean).
      option :user_info_class, default: "Doorkeeper::OpenidConnect::UserInfo"

      # Doorkeeper OpenID Request model class.
      #
      # @return [ActiveRecord::Base, Mongoid::Document, Sequel::Model]
      #
      def open_id_request_model
        @open_id_request_model ||= open_id_request_class.to_s.constantize
      end

      def id_token_model
        resolve_validated_model(:id_token, id_token_class, IdToken)
      end

      def user_info_model
        resolve_validated_model(:user_info, user_info_class, UserInfo)
      end

      # How the library instantiates each configured model: the ID token is
      # built with `(access_token, nonce)` in the authorization flows and with
      # just `(access_token)` in the token response, while the UserInfo
      # response is always built with `(access_token)`. A custom initializer
      # must stay callable with every one of these argument counts.
      INSTANTIATION_SIGNATURES = {
        id_token: { arg_counts: [1, 2], description: "(access_token, nonce = nil)" },
        user_info: { arg_counts: [1], description: "(access_token)" },
      }.freeze

      private

      # Resolves an `id_token_class` / `user_info_class` override to its class
      # and validates that it inherits from the corresponding default. The
      # ancestry check replaced the earlier method-presence list: presence
      # could be satisfied by any class (ActiveSupport defines `as_json` on
      # `Object`), while inheritance also carries the security-critical
      # behavior — required-claim enforcement, the claim merge order, nonce
      # and `at_hash` handling — that a from-scratch implementation would
      # have to reproduce. Both resolution and validation happen lazily at
      # first use rather than inside `Doorkeeper::OpenidConnect.configure`:
      # constantizing an app-defined class while initializers run breaks
      # zeitwerk on Rails 7+, because reloadable constants must not be
      # referenced during boot — the same reason `open_id_request_model`
      # constantizes lazily. The class is also deliberately not memoized, so
      # code reloading in development never hands back a stale class; only
      # the validation result is cached, keyed on the resolved class so a
      # reloaded class is re-validated.
      def resolve_validated_model(kind, class_name, base_model)
        # `safe_constantize` (unlike a bare `constantize` rescue) only reports
        # nil when the configured constant itself is missing; a NameError
        # raised while loading the class body still surfaces as-is.
        model = class_name.to_s.safe_constantize
        if model.nil?
          raise Errors::InvalidConfiguration,
                "The configured #{kind}_class (#{class_name}) does not resolve to a defined class"
        end

        @validated_models ||= {}
        return model if @validated_models[kind] == model

        unless model.is_a?(Class) && model <= base_model
          raise Errors::InvalidConfiguration,
                "The configured #{kind}_class (#{class_name}) must inherit from #{base_model.name}"
        end

        validate_initializer_arity!(kind, class_name, model)

        @validated_models[kind] = model
        model
      end

      # An incompatible custom `initialize` would otherwise only surface as an
      # ArgumentError at runtime, in the middle of a token or userinfo request;
      # checking it here reports the misconfiguration at first use instead,
      # alongside the other validations. Positional arities are derived from
      # `Method#parameters` (a bare `arity` cannot distinguish optional
      # parameters from a `*rest`), and required keyword arguments are rejected
      # because no call site passes any.
      def validate_initializer_arity!(kind, class_name, model)
        signature = INSTANTIATION_SIGNATURES.fetch(kind)
        return if initializer_accepts?(model, signature[:arg_counts])

        raise Errors::InvalidConfiguration,
              "The configured #{kind}_class (#{class_name}) must have an initializer " \
              "compatible with #{signature[:description]}"
      end

      def initializer_accepts?(model, arg_counts)
        parameter_types = initializer_parameter_types(model)
        return false if parameter_types.nil? || parameter_types.include?(:keyreq)

        required = parameter_types.count(:req)
        max = parameter_types.include?(:rest) ? Float::INFINITY : required + parameter_types.count(:opt)

        arg_counts.all? { |count| count.between?(required, max) }
      end

      # A class that undefines `initialize` has no definition for
      # `instance_method` to return — it raises `NameError`. Such a class
      # cannot be instantiated at all, so it is an incompatible signature like
      # any other and belongs on the same configuration-error path, rather
      # than leaking an unrelated exception out of the first request.
      # `remove_method` is deliberately not affected: lookup falls back to the
      # superclass, which is the initializer that would actually run.
      def initializer_parameter_types(model)
        model.instance_method(:initialize).parameters.map(&:first)
      rescue NameError
        nil
      end
    end
  end
end
