# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Enforces the OIDC `max_age` authorization parameter (OIDC Core 1.0
        # §3.1.2.1): when the resource owner's last authentication is older
        # than `max_age` seconds, reauthentication is required.
        module MaxAge
          private

          def handle_oidc_max_age_param!(owner)
            max_age = params[:max_age].to_i
            return unless (params[:max_age].to_s == "0" || max_age > 0) && owner

            auth_time = normalized_oidc_auth_time(owner)

            # NOTE: clock skew
            max_age = [1, max_age].max

            return unless oidc_auth_time_stale?(auth_time, max_age)

            # OIDC Core 1.0 §3.1.2.1: with `prompt=none` the Authorization Server
            # MUST NOT display any authentication UI. Reauthentication required by
            # `max_age` must therefore be reported as `login_required` instead of
            # triggering the interactive `reauthenticate_resource_owner` flow.
            # (Conflicting combinations like `prompt=none login` are still left to
            # `handle_oidc_prompt_param!`, which raises `invalid_request`.)
            raise Errors::LoginRequired if oidc_prompt_values == ["none"]

            reauthenticate_oidc_resource_owner(owner)
          end

          # Normalize non-Time values (e.g. an Integer epoch) so that the
          # staleness subtraction yields a Float of elapsed seconds rather
          # than a shifted Time value.
          def normalized_oidc_auth_time(owner)
            auth_time = resolve_oidc_auth_time(owner)
            return auth_time if !auth_time || auth_time.is_a?(Time) || auth_time.is_a?(DateTime)

            Time.zone.at(auth_time.to_i)
          end

          def oidc_auth_time_stale?(auth_time, max_age)
            !auth_time || (Time.zone.now - auth_time) > max_age
          end

          # Resolve auth_time for max_age enforcement.
          #
          # Prefers `auth_time_from_session` so that multi-session deployments can
          # return the auth_time of the *current* session rather than the user's
          # most recent login on any device (issue #150). Falls back to the legacy
          # `auth_time_from_resource_owner` with a one-time deprecation warning.
          def resolve_oidc_auth_time(owner)
            config = Doorkeeper::OpenidConnect.configuration

            if config.auth_time_from_session
              return instance_exec(session, request, &config.auth_time_from_session)
            end

            Doorkeeper::OpenidConnect::Helpers::Controller.warn_auth_time_from_resource_owner_deprecation
            instance_exec(owner, &config.auth_time_from_resource_owner)
          end
        end
      end
    end
  end
end
