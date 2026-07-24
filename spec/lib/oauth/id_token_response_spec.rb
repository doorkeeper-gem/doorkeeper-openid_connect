# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OAuth::IdTokenResponse do
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
    it "returns the id_token and state only (no expires_in per OIDC Core §3.2.2.5)" do
      expect(subject.body).to eq({
        state: pre_auth.state,
        id_token: id_token.as_jws_token,
      })
    end

    it "does not include expires_in" do
      expect(subject.body).not_to have_key(:expires_in)
    end

    context "when Doorkeeper is configured with an issuer (RFC 9207)" do
      before do
        allow(Doorkeeper::OpenidConnect).to receive(:doorkeeper_issuer)
          .and_return("https://issuer.example.com")
      end

      # RFC 9207 §2: the iss parameter of a response carrying an ID Token MUST
      # be identical to the ID Token's iss claim.
      it "includes an iss parameter identical to the ID Token's iss claim" do
        expect(subject.body[:iss]).to eq(id_token.issuer)
      end

      # The fragment is built with Rack::Utils.build_query, which
      # percent-encodes values (a URL issuer becomes iss=https%3A%2F%2F...),
      # so parse it back instead of matching the raw string.
      it "appends the iss parameter to the fragment" do
        fragment = URI.parse(subject.redirect_uri).fragment
        expect(Rack::Utils.parse_query(fragment)["iss"]).to eq(id_token.issuer)
      end
    end

    context "when Doorkeeper has no issuer configured" do
      before do
        allow(Doorkeeper::OpenidConnect).to receive(:doorkeeper_issuer).and_return(nil)
      end

      it "omits the iss parameter" do
        expect(subject.body).not_to have_key(:iss)
      end
    end
  end

  describe "#issued_token" do
    it "returns the access token issued by the authorization, for hook contexts" do
      expect(subject.issued_token).to eq(auth.token)
    end
  end

  describe "#redirect_uri" do
    it "includes id_token and state" do
      expect(subject.redirect_uri).to include("#{pre_auth.redirect_uri}#state=#{pre_auth.state}&" \
        "id_token=#{id_token.as_jws_token}")
    end

    it "does not include access_token" do
      expect(subject.redirect_uri).not_to include("access_token")
    end

    it "does not include expires_in" do
      expect(subject.redirect_uri).not_to include("expires_in")
    end
  end
end
