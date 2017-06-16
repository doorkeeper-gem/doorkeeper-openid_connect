module Doorkeeper
  module OpenidConnect
    class RpLogoutController < ::Doorkeeper::ApplicationController
      skip_before_action :verify_authenticity_token

      def show
        ## Query Parameters
        # id_token_hint (TODO: implement id_token_hint)
        #   RECOMMENDED. Previously issued ID Token passed to the logout endpoint as a hint
        #   about the End-User's current authenticated session with the Client. This is used
        #   as an indication of the identity of the End-User that the RP is requesting be
        #   logged out by the OP. The OP need not be listed as an audience of the ID Token when
        #   it is used as an id_token_hint value.
        # post_logout_redirect_uri
        #   OPTIONAL. URL to which the RP is requesting that the End-User's User Agent be
        #   redirected after a logout has been performed. The value MUST have been previously
        #   registered with the OP, either using the post_logout_redirect_uris Registration
        #   parameter or via another mechanism. If supplied, the OP SHOULD honor this request
        #   following the logout.
        # state
        #   OPTIONAL. Opaque value used by the RP to maintain state between the logout request
        #   and the callback to the endpoint specified by the post_logout_redirect_uri query
        #   parameter. If included in the logout request, the OP passes this value back to the
        #   RP using the state query parameter when redirecting the User Agent back to the RP.
        #
        ## Documentation for the Spec
        # https://openid.net/specs/openid-connect-session-1_0.html#RPLogout

        # Grab the id_token_hint
        id_token_hint = params[:id_token_hint]

        # Call the configured logout function
        instance_exec id_token_hint, &Doorkeeper::OpenidConnect.configuration.logout_resource_owner

        # Handle the post_logout_redirect_uri parameter
        if params[:post_logout_redirect_uri].present?
          begin
            redirect_uri = URI.parse(params[:post_logout_redirect_uri])
            # HACK: quick check to make sure that the domain is a venuenext.net domain.
            # TODO: this needs to be a property on the Doorkeeper::Application (allowed redirect_uris)
            # it needs to work similarly to how redirect_uri validation works in oauth2.
            if redirect_uri.host.ends_with?('venuenext.net') || redirect_uri.host.ends_with?('localhost')
              # Handle state parameter
              if params[:state].present?
                redirect_uri = uri_query_merge(redirect_uri, state: params[:state])
              end
              redirect_to redirect_uri.to_s
              return
            else
              render json: { errors: { post_logout_redirect_uri: ["Unauthorized Post Logout Redirect URI."] } }, status: :bad_request
              return
            end

          rescue URI::InvalidURIError => e
            render json: { errors: { post_logout_redirect_uri: ["Invalid URI"] } }, status: :bad_request
            return
          end
        end

        redirect_to "/"
      end

      private

      def uri_query_merge(uri, options = {})
        new_query_ar = URI.decode_www_form(uri.query || '').to_h.symbolize_keys.merge(options)
        uri.query = URI.encode_www_form([*new_query_ar])
        uri
      end
    end
  end
end
