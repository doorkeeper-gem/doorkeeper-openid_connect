# frozen_string_literal: true

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
        rescue Errors::OpenidConnectError => e
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

        def handle_oidc_error!(exception)
          # clear the previous response body to avoid a DoubleRenderError
          self.response_body = nil

          # FIXME: workaround for Rails 5, see https://github.com/rails/rails/issues/25106
          @_response_body = nil

          error_response = if exception.type == :invalid_request
                             ::Doorkeeper::OAuth::InvalidRequestResponse.new(
                               name: exception.type,
                               state: params[:state],
                               redirect_uri: params[:redirect_uri],
                               response_on_fragment: pre_auth.response_on_fragment?,
                             )
                           else
                             ::Doorkeeper::OAuth::ErrorResponse.new(
                               name: exception.type,
                               state: params[:state],
                               redirect_uri: params[:redirect_uri],
                               response_on_fragment: pre_auth.response_on_fragment?,
                             )
                           end

          response.headers.merge!(error_response.headers)

          # NOTE: Assign error_response to @authorize_response then use redirect_or_render method that are defined at
          #   doorkeeper's authorizations_controller.
          # - https://github.com/doorkeeper-gem/doorkeeper/blob/v5.5.0/app/controllers/doorkeeper/authorizations_controller.rb#L110
          # - https://github.com/doorkeeper-gem/doorkeeper/blob/v5.5.0/app/controllers/doorkeeper/authorizations_controller.rb#L52
          @authorize_response = error_response
          redirect_or_render(@authorize_response)
        end

        def handle_oidc_prompt_param!(owner)
          priority = %w[none consent login select_account]
          prompt_values = oidc_prompt_values.sort_by do |prompt|
            priority.find_index(prompt).to_i
          end

          prompt_values.each do |prompt|
            case prompt
            when "none"
              handle_oidc_prompt_none!(prompt_values, owner)
            when "login"
              reauthenticate_oidc_resource_owner(owner) if owner
            when "consent"
              if owner
                clear_oidc_response
                render :new
              end
            when "select_account"
              select_account_for_oidc_resource_owner(owner) if owner
            when "create"
              # NOTE: not supported, but not raise error.
            else
              raise Errors::InvalidRequest
            end
          end
        end

        def handle_oidc_prompt_none!(prompt_values, owner)
          raise Errors::InvalidRequest if (prompt_values - ["none"]).any?
          raise Errors::LoginRequired unless owner
          raise Errors::ConsentRequired if oidc_consent_required?(owner)

          # Issue #63: if an active token already covers the requested scopes
          # (a non-strict superset, including the exact-match case), force
          # auto-issue rather than rendering the consent form — `prompt=none`
          # forbids any interactive UI (OIDC Core §3.1.2.1).
          @_oidc_prompt_none_skip_authorization = true if oidc_matching_subset_token?(owner)
        end

        def handle_oidc_max_age_param!(owner)
          max_age = params[:max_age].to_i
          return unless (params[:max_age].to_s == "0" || max_age > 0) && owner

          auth_time = resolve_oidc_auth_time(owner)

          # Normalize non-Time values (e.g. an Integer epoch) so that the
          # subtraction below yields a Float of elapsed seconds rather than a
          # shifted Time value.
          if auth_time && !auth_time.is_a?(Time) && !auth_time.is_a?(DateTime)
            auth_time = Time.zone.at(auth_time.to_i)
          end

          # NOTE: clock skew
          max_age = [1, max_age].max

          return unless !auth_time || (Time.zone.now - auth_time) > max_age

          # OIDC Core 1.0 §3.1.2.1: with `prompt=none` the Authorization Server
          # MUST NOT display any authentication UI. Reauthentication required by
          # `max_age` must therefore be reported as `login_required` instead of
          # triggering the interactive `reauthenticate_resource_owner` flow.
          # (Conflicting combinations like `prompt=none login` are still left to
          # `handle_oidc_prompt_param!`, which raises `invalid_request`.)
          raise Errors::LoginRequired if oidc_prompt_values == ["none"]

          reauthenticate_oidc_resource_owner(owner)
        end

        def oidc_prompt_values
          # Reject blank entries so leading/duplicate spaces in the
          # space-delimited `prompt` parameter don't surface as an empty
          # value (which would otherwise be treated as an unknown prompt and
          # rejected with `invalid_request`).
          @oidc_prompt_values ||= params[:prompt].to_s.split(/ +/).reject(&:blank?).uniq
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

        def return_without_oidc_prompt_param(prompt_value)
          return_to = URI.parse(request.path)
          return_to.query = request.query_parameters.tap do |params|
            params["prompt"] = params["prompt"].to_s.sub(/\b#{prompt_value}\s*\b/, "").strip
            params.delete("prompt") if params["prompt"].blank?
          end.to_query
          return_to.to_s
        end

        def clear_oidc_response
          self.response_body = nil
          @_response_body = nil
        end

        def reauthenticate_oidc_resource_owner(owner)
          clear_oidc_response
          return_to = return_without_oidc_prompt_param("login")

          instance_exec(
            owner,
            return_to,
            &Doorkeeper::OpenidConnect.configuration.reauthenticate_resource_owner
          )

          raise Errors::LoginRequired unless performed?
        end

        def oidc_consent_required?(owner)
          !skip_authorization? && !matching_token? && !oidc_matching_subset_token?(owner)
        end

        # Returns true if the resource owner already has an active token for this
        # client whose scopes are a (non-strict) superset of the requested scopes.
        # Used to allow `prompt=none` to succeed when the client re-authorizes
        # with a narrower set of scopes (issue #63).
        #
        # Scans tokens via `find_access_token_in_batches` (same pattern as
        # upstream Doorkeeper's `find_matching_token`) so that installations
        # with many active tokens per (client, resource owner) pair do not
        # load the entire relation into memory.
        def oidc_matching_subset_token?(owner)
          return @oidc_matching_subset_token if defined?(@oidc_matching_subset_token)

          @oidc_matching_subset_token =
            if pre_auth.scopes.empty?
              false
            else
              access_token_model = Doorkeeper.config.access_token_model
              relation = access_token_model.authorized_tokens_for(pre_auth.client.id, owner)
              batch_size = Doorkeeper.configuration.token_lookup_batch_size

              match_found = false
              access_token_model.find_access_token_in_batches(relation, batch_size: batch_size) do |batch|
                if batch.any? { |token| token.scopes.scopes?(pre_auth.scopes) }
                  match_found = true
                  break
                end
              end
              match_found
            end
        end

        # Force Doorkeeper's `render_success` onto the auto-issue path when a
        # `prompt=none` subset-scope reauthorization has been validated above.
        def skip_authorization?
          return true if @_oidc_prompt_none_skip_authorization

          super
        end

        def select_account_for_oidc_resource_owner(owner)
          clear_oidc_response
          return_to = return_without_oidc_prompt_param("select_account")

          instance_exec(
            owner,
            return_to,
            &Doorkeeper::OpenidConnect.configuration.select_account_for_resource_owner
          )

          # OIDC Core 1.0 §3.1.2.6: if the account selection cannot be performed
          # the request MUST fail with `account_selection_required` rather than
          # silently continuing the authorization (mirrors the `login_required`
          # backstop in #reauthenticate_oidc_resource_owner).
          raise Errors::AccountSelectionRequired unless performed?
        end
      end
    end
  end

  Helpers::Controller.prepend OpenidConnect::Helpers::Controller
end
