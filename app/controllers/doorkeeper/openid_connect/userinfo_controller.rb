module Doorkeeper
  module OpenidConnect
    class UserinfoController < ::Doorkeeper::ApplicationController
      skip_before_action :verify_authenticity_token
      before_action -> { doorkeeper_authorize! :openid }

      def show
        resource_owner = doorkeeper_token.instance_eval(&Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token)
        user_info = Doorkeeper::OpenidConnect::Models::UserInfo.new(resource_owner)
        render json: user_info, status: :ok
      end
    end
  end
end
