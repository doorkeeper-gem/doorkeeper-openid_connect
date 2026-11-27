# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # Handles the Back-Channel Logout 1.0 §2.2 client registration metadata
    # for DynamicRegistrationRequest, which wires the validation in through
    # its `validate :backchannel_logout_session_required` declaration. The
    # mixin reads the request's `@params` and reports failures through
    # `@error_description`, like the validations living in the request class
    # itself.
    module BackchannelLogoutRegistrationMixin
      def backchannel_logout_session_required?
        value = @params[:backchannel_logout_session_required]
        ActiveModel::Type::Boolean.new.cast(value) || false
      end

      private

      # Back-Channel Logout 1.0 §2.2: `backchannel_logout_session_required`
      # declares that the RP requires a `sid` claim in its Logout Tokens.
      # This server issues sub-based Logout Tokens without `sid` (the
      # discovery document advertises
      # `backchannel_logout_session_supported: false`), so accepting such a
      # registration would guarantee that every Logout Token the RP later
      # receives fails its validation — reject it up front instead.
      #
      # When the server does not offer back-channel logout at all (see
      # `Doorkeeper::OpenidConnect.backchannel_logout_enabled?` — nothing is
      # advertised in the discovery document then), the parameter is ignored
      # like any other unknown client metadata (RFC 7591 §2) — matching how
      # the controller drops `backchannel_logout_uri` itself in that case.
      def validate_backchannel_logout_session_required
        return true unless Doorkeeper::OpenidConnect.backchannel_logout_enabled?
        return true unless backchannel_logout_session_required?

        @error_description =
          "backchannel_logout_session_required is not supported: this server issues " \
          "Logout Tokens identifying the user via sub only, without a sid claim " \
          "(backchannel_logout_session_supported is false)"
        false
      end
    end
  end
end
