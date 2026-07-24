# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Errors
      class OpenidConnectError < StandardError
        def type
          self.class.name.demodulize.underscore.to_sym
        end
      end

      # internal errors
      class InvalidConfiguration < OpenidConnectError; end

      # Raised when a REQUIRED ID Token claim (OIDC Core §2: iss/sub/aud/exp/iat)
      # resolves to a blank value, which would otherwise be silently dropped and
      # produce a non-conformant ID Token.
      class MissingRequiredClaim < OpenidConnectError
        attr_reader :claim

        def initialize(claim)
          @claim = claim
          super(I18n.translate("doorkeeper.openid_connect.errors.messages.missing_required_claim", claim: claim))
        end
      end

      class MissingConfiguration < OpenidConnectError
        def initialize
          super("Configuration for Doorkeeper OpenID Connect missing. Do you have doorkeeper_openid_connect initializer?")
        end
      end

      # Errors that translate into an OAuth 2.0 / OIDC error response reported
      # back to the client via a redirect, as opposed to the internal
      # server-side errors above (a misconfigured server must surface as a 500,
      # not be leaked to the client as a bogus authorization error).
      class AuthorizationError < OpenidConnectError; end

      # OAuth 2.0 errors
      # https://tools.ietf.org/html/rfc6749#section-4.1.2.1
      class InvalidRequest < AuthorizationError; end

      # OpenID Connect 1.0 errors
      # http://openid.net/specs/openid-connect-core-1_0.html#AuthError
      class LoginRequired < AuthorizationError; end
      class ConsentRequired < AuthorizationError; end
      class InteractionRequired < AuthorizationError; end
      class AccountSelectionRequired < AuthorizationError; end
    end
  end
end
