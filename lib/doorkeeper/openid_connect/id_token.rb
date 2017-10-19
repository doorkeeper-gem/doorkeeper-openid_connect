module Doorkeeper
  module OpenidConnect
    class IdToken
      include ActiveModel::Validations

      attr_reader :nonce, :at_hash

      def initialize(access_token, nonce = nil, options = {})
        @access_token = access_token
        @nonce = nonce
        @resource_owner = Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token.call(access_token)
        @issued_at = Time.now
        @at_hash = calc_at_hash(access_token) if id_token_with_access_token(options[:response_type])
      end

      def claims
        res = {
          iss: issuer,
          sub: subject,
          aud: audience,
          exp: expiration,
          iat: issued_at,
          nonce: nonce,
          auth_time: auth_time,
          at_hash: at_hash
        }
      end

      def as_json(*_)
        claims.reject { |_, value| value.nil? || value == '' }
      end

      def as_jws_token
        JSON::JWT.new(as_json).sign(
          Doorkeeper::OpenidConnect.signing_key,
          Doorkeeper::OpenidConnect.signing_algorithm
        ).to_s
      end

      private

      # The at_hash is build according to the following standard:
      #
      # http://openid.net/specs/openid-connect-implicit-1_0.html#IDToken
      #
      # at_hash:
      #   REQUIRED. Access Token hash value. If the ID Token is issued with an
      #   access_token in an Implicit Flow, this is REQUIRED, which is the case
      #   for this subset of OpenID Connect. Its value is the base64url encoding
      #   of the left-most half of the hash of the octets of the ASCII
      #   representation of the access_token value, where the hash algorithm
      #   used is the hash algorithm used in the alg Header Parameter of the
      #   ID Token's JOSE Header. For instance, if the alg is RS256, hash the
      #   access_token value with SHA-256, then take the left-most 128 bits and
      #   base64url-encode them. The at_hash value is a case-sensitive string.
      def calc_at_hash(access_token)
        sha256 = Digest::SHA256.new
        token = access_token.token
        hashed_token = sha256.digest(token)
        first_half = hashed_token[0 ... hashed_token.length/2]
        Base64.urlsafe_encode64(first_half).tr("=", "")
      end

      def id_token_with_access_token(response_type)
        return false unless response_type
        id_token_and_token_flow = ["id_token", "token"]
        id_token_and_token_flow & response_type == id_token_and_token_flow
      end

      def issuer
        Doorkeeper::OpenidConnect.configuration.issuer
      end

      def subject
        Doorkeeper::OpenidConnect.configuration.subject.call(@resource_owner, @access_token.application).to_s
      end

      def audience
        @access_token.application.uid
      end

      def expiration
        (@issued_at.utc + Doorkeeper::OpenidConnect.configuration.expiration).to_i
      end

      def issued_at
        @issued_at.utc.to_i
      end

      def auth_time
        Doorkeeper::OpenidConnect.configuration.auth_time_from_resource_owner.call(@resource_owner).try(:to_i)
      end
    end
  end
end
