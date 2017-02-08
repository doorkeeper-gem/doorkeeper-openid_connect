module Doorkeeper
  module OpenidConnect
    class UserinfoController < ::Doorkeeper::ApplicationController
      skip_before_action :verify_authenticity_token
      before_action -> { doorkeeper_authorize! :openid }

      def show
        resource_owner = Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token.call(doorkeeper_token)
        user_info = Doorkeeper::OpenidConnect::UserInfo.new(resource_owner, doorkeeper_token.scopes)
        render json: user_info, status: :ok
      end
    end
  end
end
