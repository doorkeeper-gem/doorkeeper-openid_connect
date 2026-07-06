# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class DynamicClientRegistrationController < ::Doorkeeper::ApplicationMetalController
      before_action :authorize_dynamic_client_registration!

      def register
        registration = OAuth::DynamicRegistrationRequest.new(::Doorkeeper.configuration, params)

        unless registration.valid?
          render json: registration.error_response, status: :bad_request
          return
        end

        client = Doorkeeper::Application.create!(application_params(registration))
        render json: registration_response(client, registration), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: "invalid_client_params", error_description: e.record.errors.full_messages.join(", ") },
               status: :bad_request
      end

      private

      def authorize_dynamic_client_registration!
        authorizer = ::Doorkeeper::OpenidConnect.configuration.authorize_dynamic_client_registration
        return if authorizer.nil?

        return if authorized?(authorizer)

        response.headers["WWW-Authenticate"] = "Bearer error=\"invalid_token\""
        render json: {
          error: "invalid_token",
          error_description: I18n.t(
            "doorkeeper.openid_connect.errors.messages.dynamic_client_registration_unauthorized",
          ),
        }, status: :unauthorized
      end

      def authorized?(authorizer)
        if authorizer.respond_to?(:to_proc)
          instance_exec(&authorizer.to_proc)
        elsif authorizer.respond_to?(:call)
          authorizer.call(self)
        else
          authorizer
        end
      end

      def application_params(registration)
        {
          name: params[:client_name],
          redirect_uri: params[:redirect_uris] || [],
          scopes: registration.permitted_scopes,
          confidential: registration.confidential_client?,
        }
      end

      def registration_response(doorkeeper_application, registration)
        response = {
          client_id: doorkeeper_application.uid,
          client_id_issued_at: doorkeeper_application.created_at.to_i,
          redirect_uris: doorkeeper_application.redirect_uri.split,
          token_endpoint_auth_method: registration.token_endpoint_auth_method,
          token_endpoint_auth_methods_supported: registration.token_endpoint_auth_methods_supported,
          response_types: registration.requested_response_types,
          grant_types: registration.requested_grant_types,
          scope: doorkeeper_application.scopes.to_s,
          application_type: registration.requested_application_type,
        }

        if registration.confidential_client?
          response[:client_secret] =
            doorkeeper_application.plaintext_secret || doorkeeper_application.secret
          # RFC 7591 §3.2.1 / OIDC Dynamic Client Registration 1.0 §3.2:
          # client_secret_expires_at is REQUIRED when a client_secret is issued.
          # Doorkeeper secrets never expire, so the value is 0 (no expiration).
          response[:client_secret_expires_at] = 0
        end

        response
      end
    end
  end
end
