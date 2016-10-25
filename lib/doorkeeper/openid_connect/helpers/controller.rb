module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        private

        def authenticate_resource_owner!
          owner = super

          if prompt_values.include?('none') && (!owner || owner.is_a?(String))
            # clear the previous response body to avoid a DoubleRenderError
            # TODO: this is currently broken on Rails 5, see
            # https://github.com/rails/rails/issues/25106
            self.response_body = nil

            error = ::Doorkeeper::OAuth::ErrorResponse.new(name: :login_required)
            response.headers.merge!(error.headers)
            render json: error.body, status: error.status
          else
            owner
          end
        end

        def prompt_values
          @prompt_values ||= params[:prompt].to_s.split(/ +/)
        end
      end
    end
  end
end
