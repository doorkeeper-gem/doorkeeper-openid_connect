module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        private

        def authenticate_resource_owner!
          super.tap do |owner|
            next unless respond_to?(:pre_auth, true)
            next unless pre_auth.scopes.include? 'openid'

            handle_prompt_param!(owner)
            handle_max_age_param!(owner)
          end
        rescue Errors::OpenidConnectError => exception
          # clear the previous response body to avoid a DoubleRenderError
          self.response_body = nil

          # FIXME: workaround for Rails 5, see https://github.com/rails/rails/issues/25106
          @_response_body = nil

          error = ::Doorkeeper::OAuth::ErrorResponse.new(name: exception.error_name)
          response.headers.merge!(error.headers)
          render json: error.body, status: error.status
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
              # HACK: To avoid double logins when a user is logged out and we get a
              #       request with prompt=login (when using devise).
              
              # Consider a login that has happened within the past 10 seconds to have fulfilled
              # the prompt=login parameter in the request.
              if owner
                auth_time = authentication_time(owner)
                if !auth_time || (Time.zone.now - auth_time) > 10.seconds
                  reauthenticate_resource_owner(owner)
                end
              end
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

          auth_time = authentication_time(owner)

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
          # TODO: maybe use Doorkeeper::AccessToken.matching_token_for once
          # https://github.com/doorkeeper-gem/doorkeeper/pull/907 is merged
          Doorkeeper::AccessToken.where(
            application_id: pre_auth.client.id,
            resource_owner_id: owner.id,
            revoked_at: nil,
          ).select do |token|
            Doorkeeper::AccessToken.scopes_match?(token.scopes, pre_auth.scopes, nil)
          end
        end

        private

        def authentication_time(owner)
          instance_exec(owner, &Doorkeeper::OpenidConnect.configuration.auth_time_from_resource_owner)
        end
      end
    end
  end

  Helpers::Controller.send :prepend, OpenidConnect::Helpers::Controller
end
