# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class UserinfoController < ::Doorkeeper::ApplicationMetalController
      before_action -> { doorkeeper_authorize! :openid }

      def show
        user_info = Doorkeeper::OpenidConnect.configuration.user_info_model.new(doorkeeper_token)

        # A token can carry the openid scope yet resolve to no end user — a
        # client_credentials token, or an owner deleted after issuance. The
        # UserInfo response is a statement about the End-User, so such a token
        # is not valid at this endpoint: answer with RFC 6750's 401
        # invalid_token instead of letting the claim generators dereference a
        # nil owner (500).
        if user_info.respond_to?(:resource_owner) && user_info.resource_owner.nil?
          render_resource_owner_missing_error
        else
          render json: user_info, status: :ok
        end
      end

      private

      def render_resource_owner_missing_error
        error = Doorkeeper::OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
        response.headers.merge!(error.headers)
        render json: error.body, status: error.status
      end
    end
  end
end
