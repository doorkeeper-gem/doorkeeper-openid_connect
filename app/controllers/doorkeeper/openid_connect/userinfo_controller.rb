module Doorkeeper
  module OpenidConnect
    class UserinfoController < ::Doorkeeper::ApplicationController
      include Doorkeeper::Helpers::Controller

      def show
        if doorkeeper_token && doorkeeper_token.accessible?
          resource_owner = doorkeeper_token.instance_eval(&Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token)
          user_info = Doorkeeper::OpenidConnect::Models::UserInfo.new(resource_owner)
          render json: user_info, status: :ok
        else
          error = OAuth::ErrorResponse.new(name: :invalid_request)
          response.headers.merge!(error.headers)
          render json: error.body, status: error.status
        end
      end
    end
  end
end
