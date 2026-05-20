# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::UserInfo do
  subject { described_class.new token }

  let(:user) { create :user, name: "Joe" }
  let(:token) { create :access_token, resource_owner_id: user.id, scopes: scopes }
  let(:scopes) { "openid" }

  describe "#claims" do
    it "returns all accessible claims" do
      expect(subject.claims).to eq({
        sub: user.id.to_s,
        created_at: user.created_at.to_i,
        variable_name: "openid-name",
        token_id: token.id,
        both_responses: "both",
        user_info_response: "user_info",
      })
    end

    context "with a grant for the profile scopes" do
      let(:scopes) { "openid profile" }

      it "returns additional profile claims" do
        expect(subject.claims).to eq({
          sub: user.id.to_s,
          name: "Joe",
          created_at: user.created_at.to_i,
          updated_at: user.updated_at.to_i,
          variable_name: "profile-name",
          token_id: token.id,
          both_responses: "both",
          user_info_response: "user_info",
        })
      end
    end

    context "when a custom claim collides with the protected sub claim" do
      before do
        Doorkeeper::OpenidConnect.configure do
          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          subject do |resource_owner|
            resource_owner.id
          end

          claims do
            claim(:sub, scope: :openid, response: [:user_info]) { "SPOOFED-SUB" }
          end
        end
      end

      it "does not let a custom claim override the canonical subject" do
        expect(subject.claims[:sub]).to eq user.id.to_s
      end
    end
  end

  describe "#as_json" do
    it "returns claims with nil values and empty strings removed" do
      allow(subject).to receive(:claims).and_return({
        nil: nil,
        empty: "",
        blank: " ",
      })

      expect(subject.as_json).to eq({
        blank: " "
      })
    end
  end
end
