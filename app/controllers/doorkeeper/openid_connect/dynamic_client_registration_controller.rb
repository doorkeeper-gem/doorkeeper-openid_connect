# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class DynamicClientRegistrationController < ::Doorkeeper::ApplicationMetalController
      include GrantTypesSupportedMixin

      def register
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
          confidential: false,
        }
      end

      def registration_response(doorkeeper_application)
        doorkeeper_config = ::Doorkeeper.configuration

        {
          client_secret: doorkeeper_application.plaintext_secret || doorkeeper_application.secret,
          client_id: doorkeeper_application.uid,
          client_id_issued_at: doorkeeper_application.created_at.to_i,
          redirect_uris: doorkeeper_application.redirect_uri.split,
          token_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post],
          response_types: doorkeeper_config.authorization_response_types,
          grant_types: grant_types_supported(doorkeeper_config),
          scope: doorkeeper_application.scopes.to_s,
          application_type: "web"
        }
      end
    end
  end
end
