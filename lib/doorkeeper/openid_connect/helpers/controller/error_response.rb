# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Renders OpenID Connect authorization errors (`login_required`,
        # `consent_required`, ...) through Doorkeeper's OAuth response objects.
        module ErrorResponse
          private

          def handle_oidc_error!(exception)
            clear_oidc_response

            # `issuer` feeds the RFC 9207 `iss` parameter on errors redirected
            # back to the client (doorkeeper-gem/doorkeeper#1849); Doorkeeper
            # itself gates the emission on redirectability and on the issuer
            # being configured. Versions predating #1849 simply ignore the
            # attribute, so no version guard is needed.
            error_response = oidc_error_response_class(exception).new(
              name: exception.type,
              state: params[:state],
              redirect_uri: params[:redirect_uri],
              response_on_fragment: pre_auth.response_on_fragment?,
              issuer: Doorkeeper::OpenidConnect.doorkeeper_issuer,
            )

            response.headers.merge!(error_response.headers)

            # NOTE: Assign error_response to @authorize_response then use the
            #   redirect_or_render method defined by doorkeeper's
            #   authorizations_controller.
            # - https://github.com/doorkeeper-gem/doorkeeper/blob/v5.5.0/app/controllers/doorkeeper/authorizations_controller.rb#L110
            # - https://github.com/doorkeeper-gem/doorkeeper/blob/v5.5.0/app/controllers/doorkeeper/authorizations_controller.rb#L52
            @authorize_response = error_response
            redirect_or_render(@authorize_response)
          end

          def oidc_error_response_class(exception)
            if exception.type == :invalid_request
              ::Doorkeeper::OAuth::InvalidRequestResponse
            else
              ::Doorkeeper::OAuth::ErrorResponse
            end
          end
        end
      end
    end
  end
end
