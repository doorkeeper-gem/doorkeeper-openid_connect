# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module AuthorizationsExtension
      private

      # Whitelist the OIDC `nonce` authorization parameter so Doorkeeper
      # carries it into the PreAuthorization (see
      # Doorkeeper::OpenidConnect::OAuth::PreAuthorization#initialize, which
      # reads `attrs[:nonce]`). Without this the nonce would be dropped and
      # never make it onto the issued ID Token.
      def pre_auth_param_fields
        super.append(:nonce)
      end

      # Issue #63: on a `prompt=none` request, an earlier token whose scopes
      # cover more than the request asks for matches as well, not only one
      # with exactly the requested scopes.
      #
      # This widens the match and nothing else. Doorkeeper consults it from
      # #can_authorize_response?, after its own conditions on the client, so
      # those apply to the wider token exactly as they do to an exact one. Do
      # not move this into an override of #skip_authorization? or of
      # #can_authorize_response? itself: either one answers in Doorkeeper's
      # place and lets a public client through without consent.
      def matching_token?
        super || oidc_prompt_none_matching_token?
      end
    end
  end
end
