# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class DynamicClientRegistrationController < ::Doorkeeper::ApplicationMetalController
      include GrantTypesSupportedMixin
      include TokenEndpointAuthMethodsMixin

      def register
        unless valid_token_endpoint_auth_method?
          supported = token_endpoint_auth_methods_supported + ["none"]
          render json: {
            error: "invalid_client_metadata",
            error_description: "token_endpoint_auth_method '#{requested_token_endpoint_auth_method}' is not supported. " \
                               "Supported methods are: #{supported.join(', ')}",
          }, status: :bad_request
          return
        end

        client = Doorkeeper::Application.create!(application_params)
        render json: registration_response(client), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: "invalid_client_params", error_description: e.record.errors.full_messages.join(", ") },
          status: :bad_request
      end

      private

      def application_params
        {
          name: params.dig(:client_name),
          redirect_uri: params.dig(:redirect_uris) || [],
          scopes: params.dig(:scope),
          confidential: confidential?,
        }
      end

      def requested_token_endpoint_auth_method
        params[:token_endpoint_auth_method] || "client_secret_basic"
      end

      def confidential?
        requested_token_endpoint_auth_method != "none"
      end

      def valid_token_endpoint_auth_method?
        auth_method = params[:token_endpoint_auth_method]
        return true if auth_method.blank?

        supported = token_endpoint_auth_methods_supported + ["none"]
        supported.include?(auth_method)
      end

      def registration_response(doorkeeper_application)
        doorkeeper_config = ::Doorkeeper.configuration

        response = {
          client_id: doorkeeper_application.uid,
          client_id_issued_at: doorkeeper_application.created_at.to_i,
          redirect_uris: doorkeeper_application.redirect_uri.split,
          token_endpoint_auth_method: requested_token_endpoint_auth_method,
          response_types: doorkeeper_config.authorization_response_types,
          grant_types: grant_types_supported(doorkeeper_config),
          scope: doorkeeper_application.scopes.to_s,
          application_type: "web",
        }

        if confidential?
          response[:client_secret] = doorkeeper_application.plaintext_secret || doorkeeper_application.secret
        end

        response
      end
    end
  end
end
