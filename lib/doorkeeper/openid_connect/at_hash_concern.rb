# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # Adds the `at_hash` claim required when an ID Token is issued alongside an
    # access token — the `id_token token` response type, which OpenID Connect
    # Core §3.2 defines as part of the Implicit Flow, not the Hybrid Flow of §3.3
    # (whose response types this gem does not implement).
    #
    # The host object must implement `#claims`, expose the access token via an
    # `#access_token` reader, and resolve its signing key via `#selected_key` —
    # all provided by `Doorkeeper::OpenidConnect::IdToken`, which configured
    # `id_token_class` overrides must inherit from.
    module AtHashConcern
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
        # `plaintext_token`, not `token`: with a hashing token-secret
        # strategy (`hash_token_secrets`) the stored `token` is a digest,
        # while the client receives the plaintext value, so at_hash must
        # be computed over the same octets the client will hash.
        hashed_token = at_hash_digest.digest(access_token.plaintext_token)
        first_half = hashed_token[0...hashed_token.length / 2]
        Base64.urlsafe_encode64(first_half).tr("=", "")
      end

      # OIDC Core §3.2.2.10 requires the digest to match the `alg` of the ID
      # Token's actual JOSE header — derived from the key the token is signed
      # with (`selected_key`, shared with `as_jws_token`), not from the global
      # `signing_algorithm`, which a `select_key` override may diverge from.
      def at_hash_digest
        case selected_key.algorithm.to_s
        when /256\z/ then Digest::SHA256
        when /384\z/ then Digest::SHA384
        when /512\z/ then Digest::SHA512
        else Digest::SHA256
        end
      end
    end
  end
end
