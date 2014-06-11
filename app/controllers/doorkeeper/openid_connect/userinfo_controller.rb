module Doorkeeper
  module OpenidConnect
    class UserinfoController < ::Doorkeeper::ApplicationController
      def show
        if doorkeeper_token && doorkeeper_token.accessible?
          render json: { sub: doorkeeper_token.resource_owner_id },
                 status: :ok
        else
          error = OAuth::ErrorResponse.new(name: :invalid_request)
          response.headers.merge!(error.headers)
          render json: error.body, status: error.status
        end
      end
    end
  end
end
