# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::Claims::Claim do
  subject { described_class.new name: "username", scope: "profile" }

  describe "#initialize" do
    it "uses the given name" do
      expect(subject.name).to eq :username
    end

    it "uses the given scope" do
      expect(subject.scope).to eq :profile
      expect(subject.scopes).to eq [:profile]
    end

    it "accepts an array of scopes" do
      claim = described_class.new(name: "given_name", scope: [:profile, :all_data])
      expect(claim.scopes).to eq %i[profile all_data]
    end

    it "exposes the first scope via #scope for backward compatibility" do
      claim = described_class.new(name: "given_name", scope: [:profile, :all_data])
      expect(claim.scope).to eq :profile
    end

    it "symbolizes string entries in an array scope" do
      claim = described_class.new(name: "given_name", scope: ["profile", "all_data"])
      expect(claim.scopes).to eq %i[profile all_data]
    end

    it "drops nil entries in an array scope" do
      claim = described_class.new(name: "given_name", scope: [:profile, nil])
      expect(claim.scopes).to eq [:profile]
    end

    it "falls back to the default scope when an empty array is given" do
      expect(described_class.new(name: "email", scope: []).scopes).to eq [:email]
      expect(described_class.new(name: "unknown", scope: []).scopes).to eq [:profile]
    end

    it "falls back to the default scope for standard claims" do
      expect(described_class.new(name: "family_name").scope).to eq :profile
      expect(described_class.new(name: :family_name).scope).to eq :profile
      expect(described_class.new(name: "email").scope).to eq :email
      expect(described_class.new(name: :email).scope).to eq :email
      expect(described_class.new(name: "address").scope).to eq :address
      expect(described_class.new(name: :address).scope).to eq :address
      expect(described_class.new(name: "phone_number").scope).to eq :phone
      expect(described_class.new(name: :phone_number).scope).to eq :phone
    end

    it "falls back to the profile scope for non-standard claims" do
      expect(described_class.new(name: "unknown").scope).to eq :profile
    end
  end
end
