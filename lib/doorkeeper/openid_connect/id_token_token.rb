# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class IdTokenToken < IdToken
      # ToDo: Remove this class; it's only here to maintain API compatibility.
      include Doorkeeper::OpenidConnect::HybridIdTokenConcern
    end
  end
end
