# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::ClaimsBuilder do
  describe "#build" do
    it "returns an empty Hash when no claims are declared" do
      expect(described_class.new {}.build).to eq({})
    end

    it "returns a Hash of the declared claims keyed by name" do
      claims = described_class.new do
        normal_claim(:nickname) { "nick" }
        claim(:email, response: %i[id_token user_info]) { "nick@example.com" }
      end.build

      expect(claims).to be_a(Hash)
      expect(claims.keys).to eq %i[nickname email]
      expect(claims.values).to all(be_a(Doorkeeper::OpenidConnect::Claims::NormalClaim))
      expect(claims[:email].response).to eq %i[id_token user_info]
    end

    it "keys a claim declared with a String name by its Symbol name" do
      claims = described_class.new do
        claim("nickname") { "nick" }
      end.build

      expect(claims.keys).to eq %i[nickname]
      expect(claims[:nickname].name).to eq :nickname
    end

    it "lets a later declaration of the same claim replace the earlier one" do
      claims = described_class.new do
        claim(:nickname) { "first" }
        claim("nickname") { "second" }
      end.build

      expect(claims.keys).to eq %i[nickname]
      expect(claims[:nickname].generator.call).to eq "second"
    end
  end
end
