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
        puts "*** #{Doorkeeper::OpenidConnect.configuration.issuer} ***"
        subject = instance_eval(&Doorkeeper::OpenidConnect.configuration.subject_method)
        id_token = IdToken.new(subject: subject)
        # @response.id_token = id_token.to_jws_token
        @response.id_token = id_token
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
