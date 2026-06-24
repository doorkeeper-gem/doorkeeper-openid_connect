# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class IdToken
      include ActiveModel::Validations

      # OIDC Core 1.0 §2 — these claims are REQUIRED in every ID Token, so they
      # must never be silently dropped when blank.
      REQUIRED_CLAIMS = %i[iss sub aud exp iat].freeze

      attr_reader :nonce

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
        ClaimsBuilder.generate(@access_token, :id_token).merge(
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
        ::JWT.encode(as_json,
                     Doorkeeper::OpenidConnect.signing_key.keypair,
                     Doorkeeper::OpenidConnect.signing_algorithm.to_s,
                     { typ: "JWT", kid: Doorkeeper::OpenidConnect.signing_key.kid }).to_s
      end

      private

      def issuer
        Doorkeeper::OpenidConnect.resolve_issuer(
          resource_owner: @resource_owner,
          application: @access_token.application,
        )
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
