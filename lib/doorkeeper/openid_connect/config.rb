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

        def jws_public_key(*_args)
          warn "DEPRECATION WARNING: `jws_public_key` is not needed anymore and will be removed in a future version, please remove it from config/initializers/doorkeeper_openid_connect.rb"
        end

        def jws_private_key(*args)
          warn "DEPRECATION WARNING: `jws_private_key` has been replaced by `signing_key` and will be removed in a future version, please remove it from config/initializers/doorkeeper_openid_connect.rb"
          signing_key(*args)
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

      # Doorkeeper OpenID Request model class.
      #
      # @return [ActiveRecord::Base, Mongoid::Document, Sequel::Model]
      #
      def open_id_request_model
        @open_id_request_model ||= open_id_request_class.to_s.constantize
      end
    end
  end
end
