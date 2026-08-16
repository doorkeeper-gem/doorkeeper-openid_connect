# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # A Logout Token as defined by OpenID Connect Back-Channel Logout 1.0 §2.4:
    # a signed JWT the OP sends to an RP's `backchannel_logout_uri` to request
    # that the RP log out the End-User. It is signed with the same key and
    # algorithm as ID Tokens (§2.4 recommends reusing the ID Token keys so RPs
    # can validate both against the published JWKS).
    #
    # This implementation identifies the End-User via `sub` only and never
    # emits a `sid` claim — the gem tracks no OP-side sessions. §2.4 requires
    # `sub` and/or `sid`, and per §2.6 an RP receiving a sub-only Logout Token
    # logs out all of that End-User's sessions. The discovery document
    # accordingly advertises `backchannel_logout_session_supported: false`.
    class LogoutToken
      # §2.4 — the member name identifying the logout event in the `events`
      # claim. Its value is a (possibly empty) JSON object.
      BACKCHANNEL_LOGOUT_EVENT = "http://schemas.openid.net/event/backchannel-logout"

      # §2.4 — the RECOMMENDED explicit JWT type for Logout Tokens, which lets
      # RPs reject an ID Token replayed as a Logout Token (and vice versa).
      JWT_TYP = "logout+jwt"

      # §2.4 — `iss`, `aud`, `iat`, `exp`, `jti` and `events` are REQUIRED in
      # every Logout Token. `sub` is conditionally required by the spec (`sub`
      # and/or `sid` MUST be present), but this implementation never emits
      # `sid`, so `sub` is required here as well.
      REQUIRED_CLAIMS = %i[iss sub aud iat exp jti events].freeze

      attr_reader :resource_owner, :application

      def initialize(resource_owner, application, expires_in = Doorkeeper::OpenidConnect.configuration.expiration)
        @resource_owner = resource_owner
        @application = application
        @issued_at = Time.zone.now
        @expires_in = expires_in
        @jti = SecureRandom.uuid
      end

      # NOTE: unlike IdToken#claims this deliberately does not merge the
      # configured custom claims: a Logout Token is a logout signal, not a
      # profile document, and §2.4 prohibits a `nonce` claim outright — which
      # holds by construction because only the registered claims below are
      # ever emitted.
      def claims
        {
          iss: issuer,
          sub: subject,
          aud: audience,
          iat: issued_at,
          exp: expiration,
          jti: @jti,
          events: { BACKCHANNEL_LOGOUT_EVENT => {} },
        }
      end

      def as_json(*_)
        claims.each do |key, value|
          # Every claim this token emits is REQUIRED (see REQUIRED_CLAIMS), so
          # a blank value must surface as a misconfiguration instead of being
          # dropped and producing a Logout Token conforming RPs reject.
          raise Errors::MissingRequiredClaim, key if value.nil? || value == ""
        end

        claims
      end

      def as_jws_token
        ::JWT.encode(as_json,
                     Doorkeeper::OpenidConnect.signing_key.keypair,
                     Doorkeeper::OpenidConnect.signing_algorithm.to_s,
                     { typ: JWT_TYP, kid: Doorkeeper::OpenidConnect.signing_key.kid }).to_s
      end

      def issuer
        @issuer ||= Doorkeeper::OpenidConnect.resolve_issuer(
          resource_owner: @resource_owner,
          application: @application,
        )
      end

      private

      def subject
        Doorkeeper::OpenidConnect.configuration.subject.call(
          @resource_owner,
          @application,
        ).to_s
      end

      def audience
        @application.try(:uid)
      end

      def expires_in
        if @expires_in.respond_to?(:call)
          @expires_in.call(@resource_owner, @application)
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
    end
  end
end
