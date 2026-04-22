# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::DynamicClientRegistrationController, type: :controller do
  before do
    Doorkeeper::OpenidConnect.configure do
      issuer "dummy"
      dynamic_client_registration true
    end

    Rails.application.reload_routes!
  end

  describe "#register" do
    it "creates a Doorkeeper::Application" do
      redirect_uris = [
        'https://test.host/registration_success',
        'https://test.host/registration_success_second_location',
      ]

      post :register, params: {
        client_name: "dummy_client",
        redirect_uris: redirect_uris,
        scope: "public"
      }

      expect(response.status).to eq 201
      expect(Doorkeeper::Application.count).to eq(1)

      doorkeeper_application = Doorkeeper::Application.first
      expect(JSON.parse(response.body)).to eq({
        'client_secret' => doorkeeper_application.plaintext_secret || doorkeeper_application.secret,
        'client_id' => doorkeeper_application.uid,
        'client_id_issued_at' => doorkeeper_application.created_at.to_i,
        'redirect_uris' => redirect_uris,
        'post_logout_redirect_uris' => [],
        'token_endpoint_auth_methods_supported' => %w[client_secret_basic client_secret_post],
        'response_types' => ['code', 'token', 'id_token', 'id_token token'],
        'grant_types' => %w[authorization_code client_credentials implicit_oidc],
        'scope' => "public",
        'application_type' => "web"
      })
    end

    it "registers post_logout_redirect_uris" do
      redirect_uris = ['https://test.host/registration_success']
      post_logout_redirect_uris = [
        'https://test.host/post_logout',
        'https://test.host/post_logout_alt',
      ]

      post :register, params: {
        client_name: "dummy_client",
        redirect_uris: redirect_uris,
        post_logout_redirect_uris: post_logout_redirect_uris,
        scope: "public"
      }

      expect(response.status).to eq 201
      expect(Doorkeeper::Application.count).to eq(1)

      doorkeeper_application = Doorkeeper::Application.first
      expect(doorkeeper_application.post_logout_redirect_uris).to eq(post_logout_redirect_uris)

      body = JSON.parse(response.body)
      expect(body['post_logout_redirect_uris']).to eq(post_logout_redirect_uris)
    end

    it "errors and returns errors" do
      post :register, params: {
        client_name: "dummy_client",
        redirect_uris: [
          'http://test.host/registration_success',
        ],
        scopes: "openid"
      }

      expect(response.status).to eq 400
      expect(Doorkeeper::Application.count).to eq(0)
      expect(JSON.parse(response.body)).to eq({
        "error" => "invalid_client_params",
        "error_description" => "Redirect URI must be an HTTPS/SSL URI."
      })
    end
  end
end
