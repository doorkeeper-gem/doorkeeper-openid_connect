# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    MAJOR = 2
    MINOR = 0
    TINY = 0
    PRE = "beta1"

    # Full version number
    VERSION = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
