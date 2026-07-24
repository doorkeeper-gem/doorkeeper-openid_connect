# frozen_string_literal: true

require "rails_helper"
require "stringio"

# The first reference to the autoloaded constant fires the deprecation warning
# in the class body; swallow it here to keep the suite output clean. The
# warning itself is asserted below by re-loading the file.
begin
  original_stderr = $stderr
  $stderr = StringIO.new
  Doorkeeper::OpenidConnect::IdTokenToken
ensure
  $stderr = original_stderr
end

describe Doorkeeper::OpenidConnect::IdTokenToken do
  subject { described_class.new(access_token, nonce) }

  let(:access_token) { create :access_token, resource_owner_id: user.id, scopes: "openid" }
  let(:user) { create :user }
  let(:nonce) { "123456" }

  before do
    allow(Time).to receive(:now) { Time.zone.at 60 }
  end

  it "warns about its deprecation when the class body is executed" do
    # `load` re-executes the class body, which re-fires the warning emitted on
    # the first (autoloaded) reference regardless of spec load order.
    expect do
      load "doorkeeper/openid_connect/id_token_token.rb"
    end.to output(/DEPRECATION WARNING: Doorkeeper::OpenidConnect::IdTokenToken is deprecated/).to_stderr
  end

  describe "#claims" do
    it "returns all default claims" do
      # access token is from http://openid.net/specs/openid-connect-core-1_0.html
      # so we can test `at_hash` value
      access_token.update(token: "jHkWEdUXMU1BwAsC4vtUsZwnNvTIxEl0z9K3vx5KF0Y")

      expect(subject.claims).to eq({
        iss: "dummy",
        sub: user.id.to_s,
        aud: access_token.application.uid,
        exp: 180,
        iat: 60,
        nonce: nonce,
        auth_time: 23,
        at_hash: "77QmUPtjPfzWtF2AnpK9RQ",
        both_responses: "both",
        id_token_response: "id_token",
      })
    end
  end

  describe "#at_hash" do
    # Per OIDC Core 1.0 §3.1.3.6 / §3.2.2.9, at_hash must use the hash algorithm
    # that matches the alg of the ID Token's JOSE header (e.g. HS512 -> SHA-512).
    let(:token_value) { "jHkWEdUXMU1BwAsC4vtUsZwnNvTIxEl0z9K3vx5KF0Y" }

    before { access_token.update(token: token_value) }

    def expected_at_hash(token, hasher)
      digest = hasher.digest(token)
      Base64.urlsafe_encode64(digest[0, digest.length / 2]).tr("=", "")
    end

    it "uses SHA-256 for the default RS256 signing algorithm" do
      expect(subject.claims[:at_hash]).to eq(expected_at_hash(token_value, Digest::SHA256))
    end

    context "when signing_algorithm is HS512" do
      before { configure_hmac }

      it "uses SHA-512" do
        expect(subject.claims[:at_hash]).to eq(expected_at_hash(token_value, Digest::SHA512))
      end
    end

    context "when signing_algorithm is ES512" do
      before { configure_ec }

      it "uses SHA-512" do
        expect(subject.claims[:at_hash]).to eq(expected_at_hash(token_value, Digest::SHA512))
      end
    end

    context "when signing_algorithm is HS384" do
      before { configure_doorkeeper("the_greatest_secret_key", :HS384) }

      it "uses SHA-384" do
        expect(subject.claims[:at_hash]).to eq(expected_at_hash(token_value, Digest::SHA384))
      end
    end

    context "when the signing algorithm name carries no digest length (e.g. EdDSA)" do
      before { configure_doorkeeper("the_greatest_secret_key", :EdDSA) }

      it "falls back to SHA-256" do
        expect(subject.claims[:at_hash]).to eq(expected_at_hash(token_value, Digest::SHA256))
      end
    end
  end
end
