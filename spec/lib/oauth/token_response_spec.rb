# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::OAuth::TokenResponse do
  subject { Doorkeeper::OAuth::TokenResponse.new token }

  let(:token) { create :access_token }
  let(:client) { Doorkeeper::OAuth::Client.new create(:application) }
  let(:pre_auth) { Doorkeeper::OAuth::PreAuthorization.new(Doorkeeper.configuration, client_id: client.uid, nonce: "123456") }
  let(:id_token) { Doorkeeper::OpenidConnect::IdToken.new token, pre_auth }

  before do
    pre_auth.valid? # triggers loading of pre_auth.client
  end

  describe "#body" do
    before do
      subject.id_token = id_token
    end

    context "with the openid scope present" do
      before do
        token.scopes = "openid email"
      end

      it "adds the ID token to the response" do
        expect(subject.body[:id_token]).to eq id_token.as_jws_token
      end
    end

    context "with the openid scope present but no id_token" do
      before do
        token.scopes = "openid email"
        subject.id_token = nil
      end

      it "adds the ID token to the response" do
        expect(subject.body[:id_token]).to be_truthy
      end

      context "when id_token_class is configured" do
        before do
          stub_const("CustomIdToken", Class.new(Doorkeeper::OpenidConnect::IdToken))
          allow(Doorkeeper::OpenidConnect.configuration).to receive(:id_token_model).and_return(CustomIdToken)
        end

        it "builds the id_token using the configured class" do
          expect(CustomIdToken).to receive(:new).and_call_original

          subject.body
        end
      end
    end

    context "with the openid scope not present" do
      before do
        token.scopes = "email"
      end

      it "does not add the ID token to the response" do
        expect(subject.body).not_to include :id_token
      end
    end

    context "with the openid scope present but no resource owner (e.g. client_credentials)" do
      let(:token) { create :access_token, resource_owner_id: nil, scopes: "openid email" }
      # Override so the outer `before { subject.id_token = id_token }` assigns
      # nil instead of eagerly instantiating an IdToken, which would defeat the
      # `not_to receive(:new)` expectation below.
      let(:id_token) { nil }

      it "does not build an ID token and does not raise" do
        expect(Doorkeeper::OpenidConnect::IdToken).not_to receive(:new)
        expect(subject.body).not_to include :id_token
      end
    end

    context "with the openid scope present but no application" do
      let(:token) { create :access_token, application: nil, scopes: "openid email" }
      # See above: keep the outer `before` from eagerly building an IdToken.
      let(:id_token) { nil }

      it "does not build an ID token (whose required aud claim would be missing) and does not raise" do
        expect(Doorkeeper::OpenidConnect::IdToken).not_to receive(:new)
        expect(subject.body).not_to include :id_token
      end
    end

    context "with the openid scope present, no application, and an ID token already preset" do
      let(:token) { create :access_token, application: nil, scopes: "openid email" }
      # Unlike the context above, the outer `before` keeps its preset here —
      # that is what the password grant does before the response is rendered
      # when `skip_client_authentication_for_password_grant` let it issue a
      # token with no application. `aud` is just as unsourceable as it is
      # without a preset, so the preset has to be discarded as well.

      it "discards the preset ID token instead of raising MissingRequiredClaim" do
        expect { subject.body }.not_to raise_error
        expect(subject.body).not_to include :id_token
      end
    end

    context "with the openid scope present but the resource owner deleted after issuance" do
      let(:user) { create :user }
      let(:token) { create :access_token, resource_owner_id: user.id, scopes: "openid email" }
      # The token still carries resource_owner_id, so the ID Token is built and
      # then discarded once its owner fails to resolve — hence no `not_to
      # receive(:new)` expectation here.
      let(:id_token) { nil }

      it "does not emit an ID token and does not raise when the owner no longer resolves" do
        user.destroy!

        expect(subject.body).not_to include :id_token
      end
    end
  end
end
