# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OAuth::IdTokenTokenResponse do
  subject { described_class.new(pre_auth, auth, id_token) }

  let(:token) { create :access_token }
  let(:application) do
    create(:application, scopes: "public")
  end
  let(:pre_auth) do
    double(
      :pre_auth,
      client: application,
      redirect_uri: "http://tst.com/cb",
      state: "state",
      scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
      error: nil,
      authorizable?: true,
      nonce: "12345",
    )
  end
  let(:owner) { build_stubbed(:user) }
  let(:auth) do
    Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
      if c.respond_to?(:issue_token!)
        c.issue_token!
      else
        c.issue_token
      end
    end
  end
  let(:id_token) { Doorkeeper::OpenidConnect::IdToken.new(token, pre_auth) }

  describe "#body" do
    it "return body response for id_token and access_token" do
      expect(subject.body).to eq({
        state: pre_auth.state,
        id_token: id_token.as_jws_token,
        access_token: auth.token.plaintext_token,
        token_type: auth.token.token_type,
        expires_in: auth.token.expires_in_seconds,
      })
    end

    context "when Doorkeeper is configured with an issuer (RFC 9207)" do
      before do
        allow(Doorkeeper::OpenidConnect).to receive(:doorkeeper_issuer)
          .and_return("https://issuer.example.com")
      end

      it "includes an iss parameter identical to the ID Token's iss claim" do
        expect(subject.body[:iss]).to eq(id_token.issuer)
      end
    end

    it "returns the plaintext access token, not the stored (possibly hashed) value" do
      allow(auth.token).to receive_messages(plaintext_token: "PLAINTEXT", token: "HASHED")

      expect(subject.body[:access_token]).to eq("PLAINTEXT")
    end
  end

  describe "#issued_token" do
    it "returns the issued access token, for hook contexts" do
      expect(subject.issued_token).to eq(auth.token)
    end
  end

  describe "#redirect_uri" do
    it "includes id_token, info of access_token and state" do
      expect(subject.redirect_uri).to include("#{pre_auth.redirect_uri}#state=#{pre_auth.state}&" \
        "id_token=#{id_token.as_jws_token}&" \
        "access_token=#{auth.token.plaintext_token}&" \
        "token_type=#{auth.token.token_type}&" \
        "expires_in=#{auth.token.expires_in_seconds}")
    end
  end
end
