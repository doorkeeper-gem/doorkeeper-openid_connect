# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # The `alg` a key is published with in the JWKS, going by its exported JWK.
    #
    # `signing_algorithm` is a single value, while `signing_key` can hold keys
    # of several types — a retired RSA key next to the EC key that replaced
    # it — so the configured algorithm is not the algorithm of every key.
    module JwkAlgorithm
      # An RSA key can be used with any of these (RFC 7518 §3.3, §3.5).
      RSA = %i[RS256 RS384 RS512 PS256 PS384 PS512].freeze

      # An EC key can be used with the one algorithm of its curve (RFC 7518
      # §3.4), listed here by JWK `crv`. secp256k1 is `P-256K` in a JWK
      # exported by ruby-jwt and `secp256k1` in RFC 8812.
      EC = {
        "P-256" => :ES256,
        "P-384" => :ES384,
        "P-521" => :ES512,
        "P-256K" => :ES256K,
        "secp256k1" => :ES256K,
      }.freeze

      # Returns the algorithm to publish for `jwk` when ID tokens are signed
      # with `signing_algorithm`, or nil when there is none to name.
      #
      # An EC key gets the algorithm of its curve whatever is configured. An
      # RSA key gets `signing_algorithm` when that is an RSA algorithm; when
      # it is not, the key is not the one signing and which RSA algorithm it
      # was used with is not known, so `alg`, which is optional (RFC 7517
      # §4.4), is left out. A key of any other type is taken to work with the
      # configured algorithm.
      def self.resolve(jwk, signing_algorithm)
        case jwk[:kty]
        when "RSA" then signing_algorithm if RSA.include?(signing_algorithm)
        when "EC" then EC[jwk[:crv]]
        else signing_algorithm
        end
      end
    end
  end
end
