# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class IdToken
      include ActiveModel::Validations

      # OIDC Core 1.0 §2 — these claims are REQUIRED in every ID Token, so they
      # must never be silently dropped when blank.
      REQUIRED_CLAIMS = %i[iss sub aud exp iat].freeze

      # The return type of `select_key`: the key material and the algorithm it
      # signs with, kept together so `at_hash` can always be computed with the
      # digest matching the algorithm in the token's actual JOSE header
      # (OIDC Core §3.2.2.10).
      SigningKey = Struct.new(:keypair, :kid, :algorithm, keyword_init: true)

      # `resource_owner` is exposed so callers can detect a token whose owner no
      # longer resolves (e.g. deleted after issuance) before serializing — the
      # `sub` claim would otherwise dereference a nil owner and raise.
      # `access_token` is the reader AtHashConcern relies on to compute
      # `at_hash`; a custom id_token_class must expose one as well.
      attr_reader :access_token, :nonce, :resource_owner

      def initialize(access_token, nonce = nil, expires_in = Doorkeeper::OpenidConnect.configuration.expiration)
        @access_token = access_token
        @nonce = nonce
        @resource_owner = Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token.call(access_token)
        @issued_at = Time.zone.now
        @expires_in = expires_in
      end

      def claims
        # NOTE: framework-controlled claims are merged last so a custom claim
        # block cannot override security-critical registered claims such as
        # `sub`, `aud`, `exp`, `iss` or `iat` in the signed ID token.
        # `@resource_owner` (resolved once in the constructor) is passed through
        # so the claims builder does not look the owner up a second time.
        ClaimsBuilder.generate(@access_token, :id_token, @resource_owner).merge(
          iss: issuer,
          sub: subject,
          aud: audience,
          exp: expiration,
          iat: issued_at,
          nonce: nonce,
          auth_time: auth_time,
        )
      end

      def as_json(*_)
        claims.each_with_object({}) do |(key, value), result|
          blank = value.nil? || value == ""

          if blank
            # A REQUIRED claim must never be silently omitted; surface the
            # misconfiguration instead of issuing a non-conformant ID Token.
            raise Errors::MissingRequiredClaim, key if REQUIRED_CLAIMS.include?(key)

            next
          end

          result[key] = value
        end
      end

      def as_jws_token
        key = selected_key

        ::JWT.encode(as_json,
                     key.keypair,
                     key.algorithm.to_s,
                     { typ: "JWT", kid: key.kid }).to_s
      end

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

      # Public: the RFC 9207 `iss` authorization response parameter must be
      # identical to this token's `iss` claim (RFC 9207 §2), so IdTokenResponse
      # reads the claim value from here instead of re-deriving it. Memoized so
      # a callable issuer resolves exactly once per token — `claims` and the
      # `iss` parameter would otherwise re-invoke it and could diverge.
      def issuer
        @issuer ||= Doorkeeper::OpenidConnect.resolve_issuer(
          resource_owner: @resource_owner,
          application: @access_token.application,
        )
      end

      private

      # `select_key` resolved exactly once per token, mirroring the `issuer`
      # memoization above: the signature (`as_jws_token`) and the `at_hash`
      # digest (`AtHashConcern`) must agree on the algorithm, so a
      # dynamic `select_key` implementation must not be re-invoked between
      # the two.
      def selected_key
        @selected_key ||= select_key
      end

      def subject
        Doorkeeper::OpenidConnect.configuration.subject.call(
          @resource_owner,
          @access_token.application,
        ).to_s
      end

      def audience
        @access_token.application.try(:uid)
      end

      def expires_in
        if @expires_in.respond_to?(:call)
          @expires_in.call(@resource_owner, @access_token.application)
        else
          @expires_in
        end
      end

      def expiration
        (@issued_at.utc + expires_in).to_i
      end

      def issued_at
        @issued_at.utc.to_i
      end

      def auth_time
        config = Doorkeeper::OpenidConnect.configuration

        if config.auth_time_from_access_token
          config.auth_time_from_access_token.call(@access_token).try(:to_i)
        else
          config.auth_time_from_resource_owner.call(@resource_owner).try(:to_i)
        end
      rescue Errors::InvalidConfiguration
        nil
      end
    end
  end
end
