# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::JwkAlgorithm do
  describe ".resolve" do
    it "returns the signing algorithm for an RSA key when it is an RSA algorithm" do
      %i[RS256 RS384 RS512 PS256 PS384 PS512].each do |algorithm|
        expect(described_class.resolve({ kty: "RSA" }, algorithm)).to eq algorithm
      end
    end

    it "returns nothing for an RSA key when the signing algorithm is not an RSA algorithm" do
      %i[ES256 HS256].each do |algorithm|
        expect(described_class.resolve({ kty: "RSA" }, algorithm)).to be_nil
      end
    end

    it "returns the algorithm of its curve for an EC key, whatever the signing algorithm" do
      curves = { "P-256" => :ES256, "P-384" => :ES384, "P-521" => :ES512, "P-256K" => :ES256K, "secp256k1" => :ES256K }

      curves.each do |crv, algorithm|
        %i[ES256 ES384 RS256].each do |signing_algorithm|
          expect(described_class.resolve({ kty: "EC", crv: crv }, signing_algorithm)).to eq algorithm
        end
      end
    end

    it "returns the signing algorithm for a key type it does not know" do
      expect(described_class.resolve({ kty: "OKP", crv: "Ed25519" }, :EdDSA)).to eq :EdDSA
    end
  end
end
