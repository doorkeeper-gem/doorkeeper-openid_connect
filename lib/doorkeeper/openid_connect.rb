require 'doorkeeper/openid_connect/version'
require 'doorkeeper/openid_connect/engine'
require 'doorkeeper/openid_connect/config'

require 'doorkeeper/openid_connect/rails/routes'

module Doorkeeper
  module OpenidConnect
    def self.configured?
      @config.present?
    end

    def self.installed?
      configured?
    end
  end
end

module Doorkeeper
  module OAuth
    class PasswordAccessTokenRequest
      private

      def after_successful_response
        puts Doorkeeper::OpenidConnect.configuration.jws_key
        @response.id_token = 'foo'
      end
    end
  end
end

module Doorkeeper
  module OAuth
    class TokenResponse
      attr_accessor :id_token
      alias_method :original_body, :body

      def body
        original_body.
          merge({:id_token => id_token}).
          reject { |_, value| value.blank? }
      end
    end
  end
end
