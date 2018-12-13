module Doorkeeper
  module OpenidConnect
    class CodeIdToken < IdToken

      def initialize(access_token, nonce, code)
        super(access_token, nonce)
        @code = code
      end

      def claims
        super.merge(c_hash: c_hash)
      end

      # The at_hash is build according to the following standard:
      #
      # http://openid.net/specs/openid-connect-core-1_0.html#ImplicitIDTValidation
      #
      #c_hash
      # Code hash value. Its value is the base64url encoding of the left-most half
      # of the hash of the octets of the ASCII representation of the code value,
      # where the hash algorithm used is the hash algorithm used in the alg Header Parameter
      # of the ID Token's JOSE Header. For instance, if the alg is HS512, hash the code value
      # with SHA-512, then take the left-most 256 bits and base64url encode them.
      # The c_hash value is a case sensitive string.
      # If the ID Token is issued from the Authorization Endpoint with a code, which is the
      # case for the response_type values code id_token and code id_token token,
      # this is REQUIRED; otherwise, its inclusion is OPTIONAL.
      def c_hash
        sha256 = Digest::SHA256.new
        token = @code.token.token
        hashed_token = sha256.digest(token)
        first_half = hashed_token[0...hashed_token.length / 2]
        Base64.urlsafe_encode64(first_half).tr('=', '')
      end
    end
  end
end
