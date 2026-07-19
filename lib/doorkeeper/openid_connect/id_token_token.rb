# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # TODO: Remove this class; it's only here to maintain API compatibility.
    # It is autoloaded (not eagerly required), so the warning below only fires
    # for code that actually references the constant.
    class IdTokenToken < IdToken
      warn "DEPRECATION WARNING: Doorkeeper::OpenidConnect::IdTokenToken is deprecated and will " \
           "be removed in a future major version. Use the id_token_class configuration with " \
           "Doorkeeper::OpenidConnect::HybridIdTokenConcern instead."

      include Doorkeeper::OpenidConnect::HybridIdTokenConcern
    end
  end
end
