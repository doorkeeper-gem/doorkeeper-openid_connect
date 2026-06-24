# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class IdTokenToken < IdToken
      def claims
        super.merge(at_hash: at_hash)
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
      def at_hash
        hashed_token = at_hash_digest.digest(@access_token.token)
        first_half = hashed_token[0...hashed_token.length / 2]
        Base64.urlsafe_encode64(first_half).tr("=", "")
      end

      def at_hash_digest
        case Doorkeeper::OpenidConnect.signing_algorithm.to_s
        when /256\z/ then Digest::SHA256
        when /384\z/ then Digest::SHA384
        when /512\z/ then Digest::SHA512
        else Digest::SHA256
        end
      end
    end
  end
end
