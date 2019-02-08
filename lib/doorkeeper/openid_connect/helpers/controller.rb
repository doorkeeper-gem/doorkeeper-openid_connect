module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        private

        def authenticate_resource_owner!
          super.tap do |owner|
            next unless respond_to?(:pre_auth, true)
            next unless pre_auth.client && pre_auth.scopes.include?('openid')

            handle_prompt_param!(owner)
            handle_max_age_param!(owner)
          end
        rescue Errors::OpenidConnectError => exception
          # clear the previous response body to avoid a DoubleRenderError
          self.response_body = nil

          # FIXME: workaround for Rails 5, see https://github.com/rails/rails/issues/25106
          @_response_body = nil

          error = ::Doorkeeper::OAuth::ErrorResponse.new(name: exception.error_name, state: params[:state], redirect_uri: params[:redirect_uri])
          response.headers.merge!(error.headers)

          if error.redirectable?
            render json: error.body, status: :found, location: error.redirect_uri
          else
            render json: error.body, status: error.status
          end
        end

        def handle_prompt_param!(owner)
          prompt_values ||= params[:prompt].to_s.split(/ +/).uniq

          prompt_values.each do |prompt|
            case prompt
            when 'none' then
              raise Errors::InvalidRequest if (prompt_values - [ 'none' ]).any?
              raise Errors::LoginRequired unless owner
              raise Errors::ConsentRequired unless matching_tokens_for_resource_owner(owner).present?
            when 'login' then
              reauthenticate_resource_owner(owner) if owner
            when 'consent' then
              matching_tokens_for_resource_owner(owner).map(&:destroy)
            when 'select_account' then
              # TODO: let the user implement this
              raise Errors::AccountSelectionRequired
            else
              raise Errors::InvalidRequest
            end
          end
        end

        def handle_max_age_param!(owner)
          max_age = params[:max_age].to_i
          return unless max_age > 0 && owner

          auth_time = instance_exec owner,
            &Doorkeeper::OpenidConnect.configuration.auth_time_from_resource_owner

          if !auth_time || (Time.zone.now - auth_time) > max_age
            reauthenticate_resource_owner(owner)
          end
        end

        def reauthenticate_resource_owner(owner)
          return_to = URI.parse(request.path)
          return_to.query = request.query_parameters.tap do |params|
            params['prompt'] = params['prompt'].to_s.sub(/\blogin\s*\b/, '').strip
            params.delete('prompt') if params['prompt'].blank?
          end.to_query

          instance_exec owner, return_to.to_s,
            &Doorkeeper::OpenidConnect.configuration.reauthenticate_resource_owner

          raise Errors::LoginRequired unless performed?
        end

        def matching_tokens_for_resource_owner(owner)
          Doorkeeper::AccessToken.authorized_tokens_for(pre_auth.client.id, owner.id).select do |token|
            # FIXME: this is just an experiment to verify the behaviour of Doorkeeper::AccessToken.scopes_match?
            # Doorkeeper::AccessToken.scopes_match?(token.scopes, pre_auth.scopes, pre_auth.client.scopes)

            token_scopes = token.scopes
            param_scopes = pre_auth.scopes
            app_scopes = pre_auth.client.scopes

            return true if token_scopes.empty? && param_scopes.empty?

            Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
              param_scopes.to_s,
              token_scopes
            ) &&
            Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
              param_scopes.to_s,
              Doorkeeper.configuration.scopes,
              app_scopes
            )
          end
        end
      end
    end
  end

  Helpers::Controller.send :prepend, OpenidConnect::Helpers::Controller
end
