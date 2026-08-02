# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::Claims::NormalClaim do
  subject { described_class.new(name: "name", scope: :profile, generator: generator) }

  let(:generator) { ->(user) { user.name } }

  it "exposes the generator" do
    expect(subject.generator).to eq generator
  end

  describe "#type" do
    it "is :normal" do
      expect(subject.type).to eq :normal
    end
  end
end
