# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class IdTokenResponse < BaseResponse
      include OAuth::Helpers

      attr_accessor :pre_auth, :auth, :id_token

      def initialize(pre_auth, auth, id_token)
        super()
        @pre_auth = pre_auth
        @auth = auth
        @id_token = id_token
      end

      def redirectable?
        true
      end

      def body
        {
          state: pre_auth.state,
          id_token: id_token.as_jws_token,
        }.merge(iss_parameter)
      end

      def redirect_uri
        Authorization::URIBuilder.uri_with_fragment(pre_auth.redirect_uri, body)
      end

      private

      # RFC 9207 Authorization Server Issuer Identification. Emitted only when
      # Doorkeeper itself is configured with an issuer, mirroring the gating of
      # Doorkeeper's CodeResponse and its advertised
      # `authorization_response_iss_parameter_supported` metadata flag. The
      # value is this response's ID Token `iss` claim: RFC 9207 §2 requires the
      # `iss` parameter to be identical to the `iss` claim of an ID Token
      # returned from the authorization endpoint.
      def iss_parameter
        return {} if Doorkeeper::OpenidConnect.doorkeeper_issuer.blank?

        { iss: id_token.issuer }
      end
    end
  end
end
