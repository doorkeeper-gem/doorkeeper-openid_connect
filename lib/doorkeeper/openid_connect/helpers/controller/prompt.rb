# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Handles the OIDC `prompt` authorization parameter (OIDC Core 1.0
        # §3.1.2.1): `none`, `login`, `consent`, `select_account`.
        module Prompt
          private

          def handle_oidc_prompt_param!(owner)
            priority = %w[none consent login select_account]
            prompt_values = oidc_prompt_values.sort_by do |prompt|
              priority.find_index(prompt).to_i
            end

            prompt_values.each do |prompt|
              apply_oidc_prompt!(prompt, prompt_values, owner)
            end
          end

          def apply_oidc_prompt!(prompt, prompt_values, owner)
            case prompt
            when "none"
              handle_oidc_prompt_none!(prompt_values, owner)
            when "login"
              handle_oidc_prompt_login!(owner)
            when "consent"
              handle_oidc_prompt_consent!(owner)
            when "select_account"
              select_account_for_oidc_resource_owner(owner)
            when "create"
              # NOTE: not supported, but does not raise an error.
            else
              raise Errors::InvalidRequest
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

          def handle_oidc_prompt_login!(owner)
            reauthenticate_oidc_resource_owner(owner) if owner
          end

          def handle_oidc_prompt_consent!(owner)
            return unless owner

            clear_oidc_response
            render :new
          end

          def oidc_prompt_values
            # Reject blank entries so leading/duplicate spaces in the
            # space-delimited `prompt` parameter don't surface as an empty
            # value (which would otherwise be treated as an unknown prompt and
            # rejected with `invalid_request`).
            @oidc_prompt_values ||= params[:prompt].to_s.split(/ +/).reject(&:blank?).uniq
          end

          def return_without_oidc_prompt_param(prompt_value)
            return_to = URI.parse(request.path)
            return_to.query = request.query_parameters.tap do |params|
              params["prompt"] = params["prompt"].to_s.sub(/\b#{prompt_value}\s*\b/, "").strip
              params.delete("prompt") if params["prompt"].blank?
            end.to_query
            return_to.to_s
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
  end
end
