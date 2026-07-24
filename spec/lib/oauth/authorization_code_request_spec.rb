# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::OAuth::AuthorizationCodeRequest do
  subject do
    Doorkeeper::OAuth::AuthorizationCodeRequest.new(server, grant, client).tap do |request|
      request.instance_variable_set "@response", response
      request.instance_variable_set("@access_token", token)
    end
  end

  let(:server) { double }
  let(:client) { double }
  let(:grant) { create :access_grant, openid_request: openid_request }
  let(:openid_request) { create :openid_request, nonce: "123456" }
  let(:token) { create :access_token, scopes: "openid" }
  let(:response) { Doorkeeper::OAuth::TokenResponse.new token }
  let(:openid_request_class) { Doorkeeper::OpenidConnect.configuration.open_id_request_model }

  describe "#after_successful_response" do
    it "adds the ID token to the response when the openid scope is granted" do
      subject.send :after_successful_response

      expect(response.id_token).to be_a Doorkeeper::OpenidConnect::IdToken
      expect(response.id_token.nonce).to eq "123456"
    end

    it "destroys the OpenID request record" do
      grant.save!

      expect do
        subject.send :after_successful_response
      end.to change(openid_request_class, :count).by(-1)
    end

    it "skips the nonce if not present" do
      grant.openid_request.nonce = nil
      subject.send :after_successful_response

      expect(response.id_token.nonce).to be_nil
    end

    it "attaches the ID token before the after_successful_strategy_response hook fires" do
      id_token_at_hook_time = :hook_not_called
      allow(Doorkeeper.config).to receive(:after_successful_strategy_response).and_return(
        ->(_request, resp) { id_token_at_hook_time = resp.id_token },
      )

      subject.send :after_successful_response

      expect(id_token_at_hook_time).to be_a Doorkeeper::OpenidConnect::IdToken
    end

    context "when the access token does not include the openid scope" do
      let(:token) { create :access_token, scopes: "public" }
      let(:grant) { create :access_grant, openid_request: nil }

      it "does not build an ID token" do
        expect(Doorkeeper::OpenidConnect::IdToken).not_to receive(:new)

        subject.send :after_successful_response

        expect(response.id_token).to be_nil
      end
    end

    context "when id_token_class is configured" do
      before do
        stub_const("CustomIdToken", Class.new(Doorkeeper::OpenidConnect::IdToken))
        allow(Doorkeeper::OpenidConnect.configuration).to receive(:id_token_model).and_return(CustomIdToken)
      end

      it "builds the id_token using the configured class" do
        subject.send :after_successful_response

        expect(response.id_token).to be_a CustomIdToken
      end
    end

    context "when the grant has an OpenID request but the token lacks the openid scope" do
      let(:token) { create :access_token, scopes: "public" }

      it "destroys the OpenID request record" do
        grant.save!

        expect do
          subject.send :after_successful_response
        end.to change(openid_request_class, :count).by(-1)
      end

      it "does not build an ID token" do
        expect(Doorkeeper::OpenidConnect::IdToken).not_to receive(:new)

        subject.send :after_successful_response

        expect(response.id_token).to be_nil
      end
    end
  end
end
