# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::DynamicClientRegistrationController, type: :controller do
  let(:redirect_uris) do
    [
      'https://test.host/registration_success',
      'https://test.host/registration_success_second_location',
    ]
  end

  before do
    Doorkeeper::OpenidConnect.configure do
      issuer "dummy"
      dynamic_client_registration true
    end

    Rails.application.reload_routes!
  end

  describe "#register" do
    context "without token_endpoint_auth_method (defaults to client_secret_basic)" do
      it "creates a confidential Doorkeeper::Application" do
        post :register, params: {
          client_name: "dummy_client",
          redirect_uris: redirect_uris,
          scope: "public",
        }

        expect(response.status).to eq 201
        expect(Doorkeeper::Application.count).to eq(1)

        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.confidential).to be true

        body = JSON.parse(response.body)
        expect(body).to eq({
          'client_secret' => doorkeeper_application.plaintext_secret || doorkeeper_application.secret,
          'client_id' => doorkeeper_application.uid,
          'client_id_issued_at' => doorkeeper_application.created_at.to_i,
          'redirect_uris' => redirect_uris,
          'token_endpoint_auth_method' => 'client_secret_basic',
          'response_types' => ['code', 'token', 'id_token', 'id_token token'],
          'grant_types' => %w[authorization_code client_credentials implicit_oidc],
          'scope' => "public",
          'application_type' => "web",
        })
      end
    end

    context "with token_endpoint_auth_method 'client_secret_basic'" do
      it "creates a confidential Doorkeeper::Application" do
        post :register, params: {
          client_name: "basic_client",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "client_secret_basic",
        }

        expect(response.status).to eq 201

        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.confidential).to be true

        body = JSON.parse(response.body)
        expect(body['token_endpoint_auth_method']).to eq('client_secret_basic')
        expect(body['client_secret']).to be_present
      end
    end

    context "with token_endpoint_auth_method 'client_secret_post'" do
      it "creates a confidential Doorkeeper::Application" do
        post :register, params: {
          client_name: "post_client",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "client_secret_post",
        }

        expect(response.status).to eq 201

        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.confidential).to be true

        body = JSON.parse(response.body)
        expect(body['token_endpoint_auth_method']).to eq('client_secret_post')
        expect(body['client_secret']).to be_present
      end
    end

    context "with token_endpoint_auth_method 'none'" do
      it "creates a public Doorkeeper::Application without client_secret" do
        post :register, params: {
          client_name: "public_client",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "none",
        }

        expect(response.status).to eq 201

        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.confidential).to be false

        body = JSON.parse(response.body)
        expect(body['token_endpoint_auth_method']).to eq('none')
        expect(body).not_to have_key('client_secret')
      end
    end

    context "with unsupported token_endpoint_auth_method" do
      it "returns an error" do
        post :register, params: {
          client_name: "jwt_client",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "private_key_jwt",
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body['error']).to eq('invalid_client_metadata')
        expect(body['error_description']).to include('private_key_jwt')
      end
    end

    context "when Doorkeeper client_credentials is restricted to :from_basic" do
      before do
        Doorkeeper.configure do
          client_credentials :from_basic
        end
        Rails.application.reload_routes!
      end

      it "accepts client_secret_basic" do
        post :register, params: {
          client_name: 'restricted_basic_client',
          redirect_uris: ['https://example.com/callback'],
          token_endpoint_auth_method: 'client_secret_basic',
        }
        expect(response).to have_http_status(:created)
      end

      it "rejects client_secret_post" do
        post :register, params: {
          client_name: 'restricted_post_client',
          redirect_uris: ['https://example.com/callback'],
          token_endpoint_auth_method: 'client_secret_post',
        }
        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('invalid_client_metadata')
      end

      it "still accepts none for public clients" do
        post :register, params: {
          client_name: 'restricted_public_client',
          redirect_uris: ['https://example.com/callback'],
          token_endpoint_auth_method: 'none',
        }
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['token_endpoint_auth_method']).to eq('none')
      end
    end

    context "with invalid redirect_uris" do
      it "returns an error" do
        post :register, params: {
          client_name: "dummy_client",
          redirect_uris: [
            'http://test.host/registration_success',
          ],
          scope: "openid",
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)
        expect(JSON.parse(response.body)).to eq({
          "error" => "invalid_client_params",
          "error_description" => "Redirect URI must be an HTTPS/SSL URI.",
        })
      end
    end
  end
end
