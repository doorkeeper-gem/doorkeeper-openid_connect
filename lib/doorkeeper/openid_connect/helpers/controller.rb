module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        private

        def authenticate_resource_owner!
          owner = super
          if validate_prompt_param!(owner) && validate_max_age_param!(owner)
            owner
          end
        end

        def validate_prompt_param!(owner)
          prompt_values ||= params[:prompt].to_s.split(/ +/)
          return true unless prompt_values.include?('none') && !owner

          # clear the previous response body to avoid a DoubleRenderError
          # TODO: this is currently broken on Rails 5, see
          # https://github.com/rails/rails/issues/25106
          self.response_body = nil

          error = ::Doorkeeper::OAuth::ErrorResponse.new(name: :login_required)
          response.headers.merge!(error.headers)
          render json: error.body, status: error.status

          false
        end

        def validate_max_age_param!(owner)
          max_age = params[:max_age].to_i
          return true unless max_age.positive?

          auth_time = instance_exec owner,
            &Doorkeeper::OpenidConnect.configuration.auth_time_from_resource_owner

          if !auth_time || (Time.zone.now - auth_time) > max_age
            instance_exec owner,
              &Doorkeeper::OpenidConnect.configuration.reauthenticate_resource_owner
            false
          else
            true
          end
        end
      end
    end
  end

  Helpers::Controller.send :prepend, OpenidConnect::Helpers::Controller
end
