# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      class DynamicRegistrationRequest
        include Doorkeeper::Validations
        include Doorkeeper::OpenidConnect::TokenEndpointAuthMethodsSupportedMixin
        include Doorkeeper::OpenidConnect::GrantTypesSupportedMixin

        DEFAULT_TOKEN_ENDPOINT_AUTH_METHOD = "client_secret_basic"
        PUBLIC_CLIENT_AUTH_METHOD = "none"
        DEFAULT_APPLICATION_TYPE = "web"
        SUPPORTED_APPLICATION_TYPES = %w[web native].freeze

        validate :token_endpoint_auth_method, error: :invalid_client_metadata
        validate :application_type,           error: :invalid_client_metadata
        validate :response_types,             error: :invalid_client_metadata
        validate :grant_types,                error: :invalid_client_metadata

        def initialize(server, params)
          @server = server
          @params = params
        end

        def token_endpoint_auth_method
          @params[:token_endpoint_auth_method].presence || DEFAULT_TOKEN_ENDPOINT_AUTH_METHOD
        end

        def requested_application_type
          @params[:application_type].presence || DEFAULT_APPLICATION_TYPE
        end

        def requested_response_types
          types = Array(@params[:response_types]).compact_blank
          types.presence || server_response_types
        end

        def requested_grant_types
          types = Array(@params[:grant_types]).compact_blank
          types.presence || server_grant_types
        end

        def confidential_client?
          token_endpoint_auth_method != PUBLIC_CLIENT_AUTH_METHOD
        end

        def error_response
          { error: error.to_s, error_description: @error_description }
        end

        private

        attr_reader :server

        def validate_token_endpoint_auth_method
          return true if supported_auth_methods.include?(token_endpoint_auth_method)

          @error_description =
            "token_endpoint_auth_method '#{token_endpoint_auth_method}' is not supported. " \
            "Supported methods: #{supported_auth_methods.join(", ")}"
          false
        end

        def validate_application_type
          return true if SUPPORTED_APPLICATION_TYPES.include?(requested_application_type)

          @error_description =
            "application_type '#{requested_application_type}' is not supported. " \
            "Supported types: #{SUPPORTED_APPLICATION_TYPES.join(", ")}"
          false
        end

        def validate_response_types
          unsupported = requested_response_types - server_response_types
          return true if unsupported.empty?

          @error_description =
            "response_types #{unsupported.join(", ")} are not supported. " \
            "Supported types: #{server_response_types.join(", ")}"
          false
        end

        def validate_grant_types
          unsupported = requested_grant_types - server_grant_types
          return true if unsupported.empty?

          @error_description =
            "grant_types #{unsupported.join(", ")} are not supported. " \
            "Supported types: #{server_grant_types.join(", ")}"
          false
        end

        def server_response_types
          server.authorization_response_types
        end

        def server_grant_types
          grant_types_supported(server)
        end

        def supported_auth_methods
          token_endpoint_auth_methods_supported + [PUBLIC_CLIENT_AUTH_METHOD]
        end
      end
    end
  end
end
