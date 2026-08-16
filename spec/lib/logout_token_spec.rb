# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::LogoutToken do
  subject { described_class.new(user, application) }

  let(:application) { create :application }
  let(:user) { create :user }

  before do
    allow(Time).to receive(:now) { Time.zone.at 60 }
    allow(SecureRandom).to receive(:uuid).and_return("random-jti")
  end

  describe "#claims" do
    it "returns the Back-Channel Logout 1.0 §2.4 claims" do
      expect(subject.claims).to eq(
        iss: "dummy",
        sub: user.id.to_s,
        aud: application.uid,
        iat: 60,
        exp: 180,
        jti: "random-jti",
        events: { described_class::BACKCHANNEL_LOGOUT_EVENT => {} },
      )
    end

    it "does not contain a nonce claim (§2.4 prohibits it)" do
      expect(subject.claims).not_to have_key(:nonce)
    end

    it "does not merge the configured custom claims" do
      # The dummy initializer configures custom claims (e.g. both_responses);
      # a Logout Token is a logout signal, not a profile document.
      expect(subject.claims.keys).to match_array(described_class::REQUIRED_CLAIMS)
    end

    context "when expires_in is specified" do
      subject { described_class.new(user, application, expires_in) }

      let(:expires_in) { 10 }

      it "returns the exp claim relative to iat" do
        expect(subject.claims[:exp]).to eq(subject.claims[:iat] + expires_in)
      end
    end

    context "when the expiration is a block" do
      subject { described_class.new(user, application, expires_in) }

      let(:expires_in) { proc { |_, _| 10 } }

      it "returns the exp claim relative to iat" do
        expect(subject.claims[:exp]).to eq(subject.claims[:iat] + 10)
      end
    end

    context "when the issuer is a callable" do
      before do
        Doorkeeper::OpenidConnect.configure do
          issuer do |resource_owner, application, _request|
            "#{resource_owner.id}-#{application&.uid}"
          end

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it "passes resource_owner and application to the issuer block" do
        expect(subject.claims[:iss]).to eq "#{user.id}-#{application.uid}"
      end
    end
  end

  describe "#as_json" do
    it "returns the claims" do
      expect(subject.as_json).to eq subject.claims
    end

    described_class::REQUIRED_CLAIMS.each do |claim|
      it "raises MissingRequiredClaim when the REQUIRED #{claim} claim is blank" do
        allow(subject).to receive(:claims).and_return(subject.claims.merge(claim => nil))

        expect { subject.as_json }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::MissingRequiredClaim) do |error|
            expect(error.claim).to eq(claim)
          end
      end
    end

    context "when the application is missing" do
      let(:application) { nil }

      it "raises MissingRequiredClaim for the aud claim" do
        expect { subject.as_json }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::MissingRequiredClaim) do |error|
            expect(error.claim).to eq(:aud)
          end
      end
    end
  end

  describe "#as_jws_token" do
    shared_examples "a signed logout token" do
      it "returns the claims encoded as a JWT typed logout+jwt" do
        algorithms = [Doorkeeper::OpenidConnect.signing_algorithm.to_s]

        data, headers = ::JWT.decode subject.as_jws_token, Doorkeeper::OpenidConnect.signing_key.keypair, true, { algorithms: algorithms }

        expect(data.to_hash).to eq subject.as_json.deep_stringify_keys
        expect(headers["typ"]).to eq "logout+jwt"
        expect(headers["kid"]).to eq Doorkeeper::OpenidConnect.signing_key.kid
        expect(headers["alg"]).to eq Doorkeeper::OpenidConnect.signing_algorithm.to_s
      end
    end

    it_behaves_like "a signed logout token"

    context "when signing_algorithm is EC" do
      before { configure_ec }

      it_behaves_like "a signed logout token"
    end

    context "when signing_algorithm is HMAC" do
      before { configure_hmac }

      it_behaves_like "a signed logout token"
    end
  end
end
