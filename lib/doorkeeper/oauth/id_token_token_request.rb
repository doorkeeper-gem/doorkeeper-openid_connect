# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class IdTokenTokenRequest < IdTokenRequest
      private

      def response
        # `extend` is a no-op when the concern is already in the ancestry
        # (e.g. a configured subclass of the deprecated IdTokenToken), so the
        # same path serves the default and any custom id_token_class alike.
        id_token_token = Doorkeeper::OpenidConnect.configuration.id_token_model
                                                  .new(auth.token, pre_auth.nonce)
                                                  .extend(Doorkeeper::OpenidConnect::HybridIdTokenConcern)

        IdTokenTokenResponse.new(pre_auth, auth, id_token_token)
      end
    end
  end
end
