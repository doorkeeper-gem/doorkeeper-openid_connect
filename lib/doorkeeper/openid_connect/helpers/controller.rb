module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        private

        def authenticate_resource_owner!
          super.tap do |owner|
            next unless controller_path == Doorkeeper::Rails::Routes.mapping[:authorizations][:controllers] &&
              action_name == 'new'
            raise Errors::OpenidConnectError unless pre_auth.valid?
            next unless pre_auth.scopes.include?('openid')

            handle_prompt_param!(owner)
            handle_max_age_param!(owner)
          end
        rescue Errors::OpenidConnectError => exception
          # clear the previous response body to avoid a DoubleRenderError
          self.response_body = nil

          # FIXME: workaround for Rails 5, see https://github.com/rails/rails/issues/25106
          @_response_body = nil

          error_response = if pre_auth.valid?
            ::Doorkeeper::OAuth::ErrorResponse.new(
              name: exception.error_name,
              state: params[:state],
              redirect_uri: params[:redirect_uri]
            )
          else
            pre_auth.error_response
          end

          response.headers.merge!(error_response.headers)

          if error_response.redirectable?
            render json: error_response.body, status: :found, location: error_response.redirect_uri
          else
            render json: error_response.body, status: error_response.status
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
              render :new
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
            Doorkeeper::AccessToken.scopes_match?(token.scopes, pre_auth.scopes, pre_auth.client.scopes)
          end
        end
      end
    end
  end

  Helpers::Controller.send :prepend, OpenidConnect::Helpers::Controller
end
