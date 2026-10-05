# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::ClaimsHash do
  subject(:claims) do
    Doorkeeper::OpenidConnect::ClaimsBuilder.new do
      normal_claim(:nickname) { "nick" }
      claim(:email, response: %i[id_token user_info]) { "nick@example.com" }
    end.build
  end

  before { described_class.reset_deprecation_warning! }

  it "is a Hash of the declared claims keyed by Symbol name" do
    expect(claims).to be_a(Hash)
    expect(claims.keys).to eq %i[nickname email]
    expect(claims[:email].response).to eq %i[id_token user_info]
  end

  it "keys a claim declared with a String name by its Symbol name" do
    claims = Doorkeeper::OpenidConnect::ClaimsBuilder.new { claim("nickname") { "nick" } }.build

    expect(claims.keys).to eq %i[nickname]
  end

  it "returns a plain Hash from to_h" do
    expect(claims.to_h).to be_an_instance_of(Hash)
    expect(claims.to_h.keys).to eq %i[nickname email]
  end

  it "reads Symbol keys without a deprecation warning" do
    expect { claims[:nickname] }.not_to output.to_stderr
  end

  describe "deprecated OpenStruct-style access" do
    it "reads a claim method-style" do
      expect { expect(claims.nickname.name).to eq :nickname }.to output(/DEPRECATION WARNING/).to_stderr
    end

    it "returns nil for an undeclared claim read method-style, as OpenStruct did" do
      expect { expect(claims.not_a_claim).to be_nil }.to output(/DEPRECATION WARNING/).to_stderr
    end

    it "reads a claim with a String key" do
      expect { expect(claims["email"].name).to eq :email }.to output(/DEPRECATION WARNING/).to_stderr
    end

    it "writes a claim method-style under its Symbol name" do
      replacement = claims[:email]

      expect { claims.nickname = replacement }.to output(/DEPRECATION WARNING/).to_stderr
      expect(claims[:nickname]).to equal(replacement)
    end

    it "writes a claim with a String key under its Symbol name" do
      replacement = claims[:email]

      expect { claims["nickname"] = replacement }.to output(/DEPRECATION WARNING/).to_stderr
      expect(claims.keys).to eq %i[nickname email]
      expect(claims[:nickname]).to equal(replacement)
    end

    it "digs with a String key" do
      claims[:extra] = { name: "extra" }

      expect { expect(claims.dig("extra", :name)).to eq "extra" }.to output(/DEPRECATION WARNING/).to_stderr
    end

    it "deletes a claim with delete_field and returns it" do
      expect { expect(claims.delete_field("nickname").name).to eq :nickname }.to output(/DEPRECATION WARNING/).to_stderr
      expect(claims.keys).to eq %i[email]
    end

    it "raises NameError from delete_field for an undeclared claim, as OpenStruct did" do
      expect { claims.delete_field(:not_a_claim) }.to raise_error(NameError, /not_a_claim/).and output.to_stderr
    end

    it "returns the block's value from delete_field for an undeclared claim" do
      expect { expect(claims.delete_field(:not_a_claim) { :default }).to eq :default }.to output.to_stderr
    end

    it "responds to declared claim names and setters" do
      expect(claims).to respond_to(:nickname)
      expect(claims).to respond_to(:anything=)
      expect(claims).not_to respond_to(:not_a_claim)
    end

    it "warns only once per process" do
      expect { claims.nickname }.to output.to_stderr
      expect { claims["email"] }.not_to output.to_stderr
    end
  end
end
