# frozen_string_literal: true

require "doorkeeper/openid_connect/helpers/controller/error_response"
require "doorkeeper/openid_connect/helpers/controller/max_age"
require "doorkeeper/openid_connect/helpers/controller/prompt"
require "doorkeeper/openid_connect/helpers/controller/token_matching"

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Emit `auth_time_from_resource_owner` deprecation at most once per process
        # to avoid spamming logs on every authorize request with `max_age`.
        @auth_time_from_resource_owner_deprecation_warned = false

        def self.warn_auth_time_from_resource_owner_deprecation
          return if @auth_time_from_resource_owner_deprecation_warned

          @auth_time_from_resource_owner_deprecation_warned = true
          warn "DEPRECATION WARNING: `auth_time_from_resource_owner` is deprecated for " \
               "`max_age` enforcement because it cannot distinguish between concurrent " \
               "sessions of the same user, which is a security issue (see " \
               "https://github.com/doorkeeper-gem/doorkeeper-openid_connect/issues/150). " \
               "Please configure `auth_time_from_session` to derive auth_time from the " \
               "current session instead. The `auth_time_from_resource_owner` callback " \
               "continues to be used as a fallback and for the `auth_time` claim on the " \
               "ID Token."
        end

        # Reset the deprecation flag (test helper).
        def self.reset_auth_time_deprecation_warning!
          @auth_time_from_resource_owner_deprecation_warned = false
        end

        # Because this module is prepended onto Doorkeeper's
        # Helpers::Controller, the included modules end up between it and
        # Doorkeeper's implementation in the ancestor chain — their `super`
        # calls (e.g. in `skip_authorization?`) still reach Doorkeeper.
        include ErrorResponse
        include MaxAge
        include Prompt
        include TokenMatching

        private

        # FIXME: remove after Doorkeeper will merge it
        def current_resource_owner
          return @current_resource_owner if defined?(@current_resource_owner)

          super
        end

        def authenticate_resource_owner!
          super.tap do |owner|
            next unless oidc_authorization_request? ||
                        non_oidc_request_with_prompt_handling_enabled?

            # When the configured resource_owner_authenticator redirects an
            # unauthenticated user, +super+ returns whatever +redirect_to+
            # returned (a truthy Integer/String), not a resource owner. Treat
            # that as "no owner" so the OIDC param handling below still runs
            # (e.g. prompt=none must yield login_required per OIDC Core
            # §3.1.2.1) without calling model methods on a non-model value.
            owner = nil if performed?

            # `max_age` stays OIDC-only (OIDC Core §3.1.2.1); `prompt` is
            # also honored on non-OIDC requests when the option is enabled.
            handle_oidc_max_age_param!(owner) if oidc_authorization_request?
            handle_oidc_prompt_param!(owner)
          end
        rescue Errors::AuthorizationError => e
          # Only OAuth/OIDC protocol errors are reported to the client. Internal
          # errors (e.g. Errors::InvalidConfiguration from an unconfigured
          # callback) must propagate as a 500 rather than being leaked to the
          # client as a spurious authorization error.
          handle_oidc_error!(e)
        end

        def oidc_authorization_request?
          authorization_request_on_authorize_endpoint? &&
            pre_auth.scopes.include?("openid")
        end

        def non_oidc_request_with_prompt_handling_enabled?
          Doorkeeper::OpenidConnect.configuration.apply_prompt_to_non_oidc_requests &&
            authorization_request_on_authorize_endpoint?
        end

        def authorization_request_on_authorize_endpoint?
          controller_path == Doorkeeper::Rails::Routes.mapping[:authorizations][:controllers] &&
            action_name == "new" &&
            pre_auth.valid?
        end

        # Clear the previous response body to avoid a DoubleRenderError when
        # rendering or redirecting again after the authenticator already
        # produced a response.
        def clear_oidc_response
          self.response_body = nil

          # FIXME: workaround for Rails 5, see https://github.com/rails/rails/issues/25106
          @_response_body = nil
        end
      end
    end
  end

  Helpers::Controller.prepend OpenidConnect::Helpers::Controller
end
