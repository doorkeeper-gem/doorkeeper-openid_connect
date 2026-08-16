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

  # Stubs the claim source so the examples can feed #as_json blank claims directly.
  # rubocop:disable RSpec/SubjectStub
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
  # rubocop:enable RSpec/SubjectStub

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

  # Back-Channel Logout 1.0 §2.4: "The same keys are used to sign and encrypt
  # Logout Tokens as are used for ID Tokens", so a custom key selection has to
  # reach Logout Tokens as well — otherwise an RP validating against the JWKS
  # the ID Tokens point at cannot verify the Logout Token it receives.
  describe "#select_key" do
    it "returns the globally configured key material, kid and algorithm" do
      key = subject.select_key

      # `signing_key` builds a fresh JWK per call, so key material is compared
      # by its PEM export rather than object identity.
      expect(key.keypair.to_pem).to eq Doorkeeper::OpenidConnect.signing_key.keypair.to_pem
      expect(key.kid).to eq Doorkeeper::OpenidConnect.signing_key.kid
      expect(key.algorithm).to eq Doorkeeper::OpenidConnect.signing_algorithm.to_s
    end

    it "resolves the global signing key once, so keypair and kid come from the same JWK" do
      # A callable `signing_key` is re-evaluated per call, so reading keypair
      # and kid from separate calls could pair values from different keys.
      expect(Doorkeeper::OpenidConnect).to receive(:signing_key).once.and_call_original

      subject.select_key
    end

    it "shares the hook with IdToken, so one override covers both token types" do
      expect(described_class.include?(Doorkeeper::OpenidConnect::SigningKeySelection))
        .to be true
      expect(Doorkeeper::OpenidConnect::IdToken.include?(Doorkeeper::OpenidConnect::SigningKeySelection))
        .to be true
    end

    context "when overridden by a subclass" do
      let(:custom_class) do
        Class.new(described_class) do
          def select_key
            Doorkeeper::OpenidConnect::SigningKeySelection::SigningKey.new(
              keypair: "per-tenant-secret",
              kid: "tenant-1",
              algorithm: "HS512",
            )
          end
        end
      end

      before { stub_const("CustomLogoutToken", custom_class) }

      it "signs the Logout Token with the selected key, algorithm and kid" do
        instance = CustomLogoutToken.new(user, application)

        data, headers = ::JWT.decode(instance.as_jws_token, "per-tenant-secret", true, { algorithms: ["HS512"] })

        expect(headers["alg"]).to eq "HS512"
        expect(headers["kid"]).to eq "tenant-1"
        expect(headers["typ"]).to eq described_class::JWT_TYP
        expect(data["sub"]).to eq user.id.to_s
      end

      it "resolves the key exactly once per token" do
        instance = CustomLogoutToken.new(user, application)
        expect(instance).to receive(:select_key).once.and_call_original

        instance.as_jws_token
        instance.as_jws_token
      end
    end
  end
end
