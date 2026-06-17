# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module TokenEndpointAuthMethodsSupportedMixin
      CLIENT_CREDENTIALS_METHOD_MAPPING = {
        from_basic: "client_secret_basic",
        from_params: "client_secret_post",
      }.freeze

      def token_endpoint_auth_methods_supported
        ::Doorkeeper.config.client_credentials_methods.filter_map do |method|
          CLIENT_CREDENTIALS_METHOD_MAPPING[method]
        end
      end
    end
  end
end
