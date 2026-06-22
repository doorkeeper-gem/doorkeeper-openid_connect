# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    MAJOR = 1
    MINOR = 10
    TINY = 2
    PRE = nil

    # Full version number
    VERSION = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
