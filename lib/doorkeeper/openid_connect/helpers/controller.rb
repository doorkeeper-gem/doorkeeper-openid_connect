# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        private

        # FIXME: remove after Doorkeeper will merge it
        def current_resource_owner
          return @current_resource_owner if defined?(@current_resource_owner)

          super
        end

        def authenticate_resource_owner!
          super.tap do |owner|
            next unless oidc_authorization_request?

            handle_oidc_prompt_param!(owner)
            handle_oidc_max_age_param!(owner)
          end
        rescue Errors::OpenidConnectError => e
          handle_oidc_error!(e)
        end

        def oidc_authorization_request?
          controller_path == Doorkeeper::Rails::Routes.mapping[:authorizations][:controllers] &&
            action_name == 'new' &&
            pre_auth.valid? &&
            pre_auth.scopes.include?('openid')
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
                             )
                           else
                             ::Doorkeeper::OAuth::ErrorResponse.new(
                               name: exception.type,
                               state: params[:state],
                               redirect_uri: params[:redirect_uri],
                             )
          end

          response.headers.merge!(error_response.headers)

          if error_response.redirectable?
            render json: error_response.body, status: :found, location: error_response.redirect_uri
          else
            render json: error_response.body, status: error_response.status
          end
        end

        def handle_oidc_prompt_param!(owner)
          prompt_values ||= params[:prompt].to_s.split(/ +/).uniq

          prompt_values.each do |prompt|
            case prompt
            when 'none'
              raise Errors::InvalidRequest if (prompt_values - ['none']).any?
              raise Errors::LoginRequired unless owner
              raise Errors::ConsentRequired if oidc_consent_required?
            when 'login'
              reauthenticate_oidc_resource_owner(owner) if owner
            when 'consent'
              render :new
            when 'select_account'
              select_account_for_oidc_resource_owner(owner)
            else
              raise Errors::InvalidRequest
            end
          end
        end

        def handle_oidc_max_age_param!(owner)
          max_age = params[:max_age].to_i
          return unless max_age > 0 && owner

          auth_time = instance_exec(
            owner,
            &Doorkeeper::OpenidConnect.configuration.auth_time_from_resource_owner
          )

          if !auth_time || (Time.zone.now - auth_time) > max_age
            reauthenticate_oidc_resource_owner(owner)
          end
        end

        def return_without_prompt_param(prompt_value)
          return_to = URI.parse(request.path)
          return_to.query = request.query_parameters.tap do |params|
            params['prompt'] = params['prompt'].to_s.sub(/\b#{prompt_value}\s*\b/, '').strip
            params.delete('prompt') if params['prompt'].blank?
          end.to_query
          return_to.to_s
        end

        def reauthenticate_oidc_resource_owner(owner)
          return_to = return_without_prompt_param('login')

          instance_exec(
            owner,
            return_to,
            &Doorkeeper::OpenidConnect.configuration.reauthenticate_resource_owner
          )

          raise Errors::LoginRequired unless performed?
        end

        def oidc_consent_required?
          !skip_authorization? && !matching_token?
        end

        def select_account_for_oidc_resource_owner(owner)
          return_to = return_without_prompt_param('select_account')

          instance_exec(
            owner,
            return_to,
            &Doorkeeper::OpenidConnect.configuration.select_account_for_resource_owner
          )
        end
      end
    end
  end

  Helpers::Controller.prepend OpenidConnect::Helpers::Controller
end
