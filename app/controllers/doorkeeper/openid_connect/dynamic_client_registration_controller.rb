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

        client = Doorkeeper.configuration.application_model.create!(application_params(registration))
        render json: registration_response(client, registration), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: record_invalid_response(e.record), status: :bad_request
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

      def record_invalid_response(record)
        {
          error: registration_error_code(record),
          error_description: record.errors.full_messages.join(", "),
        }
      end

      # RFC 7591 §3.2.2 registration error codes: `invalid_redirect_uri` for
      # redirect URI problems, `invalid_client_metadata` for everything else.
      def registration_error_code(record)
        record.errors.include?(:redirect_uri) ? "invalid_redirect_uri" : "invalid_client_metadata"
      end

      def application_params(registration)
        {
          name: params[:client_name],
          redirect_uri: params[:redirect_uris] || [],
          scopes: registration.permitted_scopes,
          confidential: registration.confidential_client?,
        }.merge(optional_column_params)
      end

      # Client metadata backed by a column that an existing installation may
      # not have migrated in yet. RFC 7591 §2 allows the server to ignore
      # client metadata it does not understand, so each parameter is simply
      # dropped when its column is missing instead of failing the
      # registration.
      def optional_column_params
        optional = {}

        if post_logout_redirect_uris_supported?
          optional[:post_logout_redirect_uris] = params[:post_logout_redirect_uris] || []
        end

        # Back-Channel Logout 1.0 §2.2 registration metadata.
        if backchannel_logout_uri_supported? && params[:backchannel_logout_uri].present?
          optional[:backchannel_logout_uri] = params[:backchannel_logout_uri]
        end

        optional
      end

      def post_logout_redirect_uris_supported?
        Doorkeeper.config.application_model.column_names.include?("post_logout_redirect_uris")
      end

      def backchannel_logout_uri_supported?
        Doorkeeper.config.application_model.column_names.include?("backchannel_logout_uri")
      end

      # One method per metadata document: the registration response echoes
      # the client metadata as RFC 7591 §3.2.1 lists it, and splitting it
      # would hide the shape of the published document.
      # rubocop:disable Metrics/AbcSize
      def registration_response(doorkeeper_application, registration)
        response = {
          client_id: doorkeeper_application.uid,
          client_id_issued_at: doorkeeper_application.created_at.to_i,
          # RFC 7591 §3.2.1: the response must include all registered client
          # metadata. The name is always present on a successfully created
          # application (the model validates its presence).
          client_name: doorkeeper_application.name,
          redirect_uris: doorkeeper_application.redirect_uri.split,
          token_endpoint_auth_method: registration.token_endpoint_auth_method,
          token_endpoint_auth_methods_supported: registration.token_endpoint_auth_methods_supported,
          response_types: registration.requested_response_types,
          grant_types: registration.requested_grant_types,
          scope: doorkeeper_application.scopes.to_s,
          application_type: registration.requested_application_type,
        }

        # Registration is optional (RP-Initiated Logout §2), so the metadata
        # field is only echoed when post-logout redirect URIs were registered.
        post_logout_uris = doorkeeper_application.post_logout_redirect_uris
        response[:post_logout_redirect_uris] = post_logout_uris if post_logout_uris.present?

        response.merge!(backchannel_logout_metadata(doorkeeper_application))

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
      # rubocop:enable Metrics/AbcSize

      # Back-Channel Logout 1.0 §2.2 client metadata, echoed only when the
      # client registered a `backchannel_logout_uri` — registration is
      # optional, like the RP-Initiated Logout metadata above. The
      # `backchannel_logout_session_required` echo makes the sub-only contract
      # explicit: registrations requiring a `sid` claim are rejected by
      # DynamicRegistrationRequest, so a registered client is always `false`
      # here.
      def backchannel_logout_metadata(doorkeeper_application)
        uri = doorkeeper_application.backchannel_logout_uri
        return {} if uri.blank?

        { backchannel_logout_uri: uri, backchannel_logout_session_required: false }
      end
    end
  end
end
