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

      # OAuth 2.0 errors
      # https://tools.ietf.org/html/rfc6749#section-4.1.2.1
      class InvalidRequest < OpenidConnectError; end

      # OpenID Connect 1.0 errors
      # http://openid.net/specs/openid-connect-core-1_0.html#AuthError
      class LoginRequired < OpenidConnectError; end
      class ConsentRequired < OpenidConnectError; end
      class InteractionRequired < OpenidConnectError; end
      class AccountSelectionRequired < OpenidConnectError; end
    end
  end
end
