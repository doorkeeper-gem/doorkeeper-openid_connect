# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::IdToken do
  subject { described_class.new(access_token, nonce) }

  let(:access_token) { create :access_token, resource_owner_id: user.id, scopes: "openid" }
  let(:user) { create :user }
  let(:nonce) { "123456" }

  before do
    allow(Time).to receive(:now) { Time.zone.at 60 }
  end

  describe "#nonce" do
    it "returns the stored nonce" do
      expect(subject.nonce).to eq "123456"
    end
  end

  describe "#issuer" do
    context "when the issuer is a callable resolving to a new value per call" do
      before do
        calls = 0
        Doorkeeper::OpenidConnect.configure do
          issuer do |_resource_owner, _application|
            calls += 1
            "https://issuer.example.com/#{calls}"
          end

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          auth_time_from_resource_owner do |resource_owner|
            resource_owner.current_sign_in_at
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it "resolves the issuer exactly once per token" do
        expect(subject.issuer).to eq "https://issuer.example.com/1"
        expect(subject.issuer).to eq "https://issuer.example.com/1"
      end

      it "returns a value identical to the ID Token iss claim (RFC 9207 §2)" do
        expect(subject.claims[:iss]).to eq subject.issuer
      end
    end
  end

  describe "#claims" do
    it "returns all default claims" do
      expect(subject.claims).to eq(
        iss: "dummy",
        sub: user.id.to_s,
        aud: access_token.application.uid,
        exp: 180,
        iat: 60,
        nonce: nonce,
        auth_time: 23,
        both_responses: "both",
        id_token_response: "id_token",
      )
    end

    context "when expires_in is specified for the token" do
      subject { described_class.new(access_token, nonce, expires_in) }

      let(:expires_in) { 10 }

      it "returns expiration claim with the specified value" do
        expect(subject.claims[:exp]).to eq(subject.claims[:iat] + expires_in)
      end
    end

    context "when the expiration is a block" do
      subject { described_class.new(access_token, nonce, expires_in) }

      let(:expires_in) { proc { |_, _| 10 } }

      it "returns expiration claim with the specified value" do
        expect(subject.claims[:exp]).to eq(subject.claims[:iat] + expires_in.call(user, access_token.application))
      end
    end

    context "when application is not set on the access token" do
      before do
        access_token.application = nil
      end

      it "returns all default claims except audience" do
        expect(subject.claims).to eq(
          iss: "dummy",
          sub: user.id.to_s,
          aud: nil,
          exp: 180,
          iat: 60,
          nonce: nonce,
          auth_time: 23,
          both_responses: "both",
          id_token_response: "id_token",
        )
      end
    end

    context "when issuer block has arity 3" do
      before do
        Doorkeeper::OpenidConnect.configure do
          issuer do |resource_owner, application, _request|
            "#{resource_owner.id}-#{application&.uid}"
          end

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          auth_time_from_resource_owner do |resource_owner|
            resource_owner.current_sign_in_at
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it "passes resource_owner and application to the issuer block" do
        claims = subject.claims
        expect(claims[:iss]).to eq "#{user.id}-#{access_token.application.uid}"
      end
    end

    context "when auth_time_from_resource_owner is not configured" do
      before do
        Doorkeeper::OpenidConnect.configure do
          issuer "dummy"

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it "builds claims without raising and omits auth_time" do
        expect { subject.claims }.not_to raise_error
        expect(subject.claims[:auth_time]).to be_nil
        expect(subject.as_json).not_to include(:auth_time)
      end
    end

    context "when auth_time_from_access_token is configured" do
      before do
        access_token.define_singleton_method(:auth_time_from_custom_mechanism) do
          @auth_time_from_custom_mechanism ||= 5.minutes.ago
        end

        Doorkeeper::OpenidConnect.configure do
          issuer "dummy"

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          auth_time_from_access_token do |access_token|
            access_token.auth_time_from_custom_mechanism
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it "uses auth_time using auth_time_from_access_token" do
        expect { subject.claims }.not_to raise_error
        expect(subject.claims[:auth_time]).to eq access_token.auth_time_from_custom_mechanism.to_i
        expect(subject.as_json).to include(:auth_time)
      end
    end

    context "when a custom claim collides with a protected registered claim" do
      before do
        Doorkeeper::OpenidConnect.configure do
          issuer "dummy"

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          auth_time_from_resource_owner do |resource_owner|
            resource_owner.current_sign_in_at
          end

          subject do |resource_owner|
            resource_owner.id
          end

          claims do
            claim(:sub, scope: :openid, response: [:id_token]) { "SPOOFED-SUB" }
            claim(:aud, scope: :openid, response: [:id_token]) { "EVIL-CLIENT" }
            claim(:exp, scope: :openid, response: [:id_token]) { 9_999_999_999 }
            claim(:iss, scope: :openid, response: [:id_token]) { "https://evil.example.com" }
          end
        end
      end

      it "does not let custom claims override iss/sub/aud/exp in the signed ID token" do
        claims = subject.claims

        expect(claims[:iss]).to eq "dummy"
        expect(claims[:sub]).to eq user.id.to_s
        expect(claims[:aud]).to eq access_token.application.uid
        expect(claims[:exp]).to eq 180
      end
    end
  end

  describe "a custom id_token_class subclass" do
    # mini implementation to make sure we can exercise subclass behavior.

    let(:custom_class) do
      Class.new(described_class) do
        def claims
          if @access_token.scopes.exists?("actor")
            super.merge(act: { sub: "impersonator" })
          else
            super
          end
        end
      end
    end

    before { stub_const("CustomIdToken", custom_class) }

    context "when scopes contains business-logic triggering behavior" do
      let(:access_token) { create :access_token, resource_owner_id: user.id, scopes: "openid actor" }

      it "reaches the override through claims, as_json, and as_jws_token" do
        instance = CustomIdToken.new(access_token, nonce)

        expect(instance.claims[:act]).to eq(sub: "impersonator")
        expect(instance.as_json[:act]).to eq(sub: "impersonator")

        algorithms = [Doorkeeper::OpenidConnect.signing_algorithm.to_s]
        decoded, = ::JWT.decode(instance.as_jws_token, Doorkeeper::OpenidConnect.signing_key.keypair, true,
                                { algorithms: algorithms })
        expect(decoded["act"]).to eq("sub" => "impersonator")
      end
    end
  end

  describe "#as_json" do
    let(:valid_claims) do
      {
        iss: "dummy",
        sub: user.id.to_s,
        aud: access_token.application.uid,
        exp: 180,
        iat: 60,
        nonce: "123456",
      }
    end

    it "removes OPTIONAL claims with nil or empty values" do
      # nonce / auth_time and custom claims are OPTIONAL, so blanks are dropped
      # while the REQUIRED claims remain present.
      allow(subject).to receive(:claims).and_return(
        valid_claims.merge(nonce: nil, auth_time: "", custom: " "),
      )

      json = subject.as_json

      expect(json).not_to include :nonce
      expect(json).not_to include :auth_time
      expect(json).to include :iss, :sub, :aud, :exp, :iat, :custom
    end

    Doorkeeper::OpenidConnect::IdToken::REQUIRED_CLAIMS.each do |claim|
      [nil, ""].each do |blank|
        it "raises MissingRequiredClaim when the REQUIRED #{claim} claim is #{blank.inspect}" do
          allow(subject).to receive(:claims).and_return(valid_claims.merge(claim => blank))

          expect { subject.as_json }
            .to raise_error(Doorkeeper::OpenidConnect::Errors::MissingRequiredClaim) do |error|
              expect(error.claim).to eq(claim)
            end
        end
      end
    end
  end

  describe "#as_jws_token" do
    shared_examples "a jws token" do
      it "returns claims encoded as JWT" do
        algorithms = [Doorkeeper::OpenidConnect.signing_algorithm.to_s]

        data, headers = ::JWT.decode subject.as_jws_token, Doorkeeper::OpenidConnect.signing_key.keypair, true, { algorithms: algorithms }

        expect(data.to_hash).to eq subject.as_json.stringify_keys
        expect(headers["kid"]).to eq Doorkeeper::OpenidConnect.signing_key.kid
        expect(headers["alg"]).to eq Doorkeeper::OpenidConnect.signing_algorithm.to_s
      end
    end

    it_behaves_like "a jws token"

    context "when signing_algorithm is EC" do
      before { configure_ec }

      it_behaves_like "a jws token"
    end

    context "when signing_algorithm is HMAC" do
      before { configure_hmac }

      it_behaves_like "a jws token"
    end
  end
end
