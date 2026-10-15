# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # Signing-key selection shared by every token this gem signs.
    #
    # ID Tokens and Logout Tokens must be signed with the same key: Back-Channel
    # Logout 1.0 §2.4 states that "the same keys are used to sign and encrypt
    # Logout Tokens as are used for ID Tokens", which is what lets an RP
    # validate both against one published JWKS. Sharing the `select_key` hook
    # here is what keeps that true for a custom implementation as well — an
    # override that returns a per-client or rotating key applies to both token
    # types instead of only the one it was written for.
    module SigningKeySelection
      # The return type of `select_key`: the key material and the algorithm it
      # signs with, kept together so `at_hash` can always be computed with the
      # digest matching the algorithm in the token's actual JOSE header
      # (OIDC Core §3.2.2.10).
      SigningKey = Struct.new(:keypair, :kid, :algorithm, keyword_init: true)

      # Override point for custom signing-key selection (per-client keys, key
      # rotation, multi-tenant setups, …). Must return an object responding to
      # `#keypair`, `#kid` and `#algorithm` — use `SigningKey` for convenience.
      # Keys returned from here are not advertised automatically: a custom
      # implementation is responsible for exposing any additional keys through
      # its own JWKS handling so clients can validate the signature.
      def select_key
        # Resolved once: `signing_key` builds a fresh JWK per call and honors
        # callable configuration, so reading `keypair` and `kid` from separate
        # calls could pair values from two different keys.
        jwk = Doorkeeper::OpenidConnect.signing_key

        SigningKey.new(
          keypair: jwk.keypair,
          kid: jwk.kid,
          algorithm: Doorkeeper::OpenidConnect.signing_algorithm.to_s,
        )
      end

      private

      # `select_key` resolved exactly once per token, mirroring the `issuer`
      # memoization: the signature (`as_jws_token`) and, for ID Tokens, the
      # `at_hash` digest (`AtHashConcern`) must agree on the algorithm, so a
      # dynamic `select_key` implementation must not be re-invoked between
      # the two.
      def selected_key
        @selected_key ||= select_key
      end
    end
  end
end
