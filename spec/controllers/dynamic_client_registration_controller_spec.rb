# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::DynamicClientRegistrationController, type: :controller do
  let(:redirect_uris) do
    [
      "https://test.host/registration_success",
      "https://test.host/registration_success_second_location",
    ]
  end

  before do
    Doorkeeper.configure do
      orm :active_record
      grant_flows %w[authorization_code client_credentials implicit_oidc]
      default_scopes :public
      optional_scopes :openid, :profile
    end

    Doorkeeper::OpenidConnect.configure do
      issuer "dummy"
      dynamic_client_registration true
    end

    Rails.application.reload_routes!
  end

  describe "#register" do
    context "when token_endpoint_auth_method is omitted" do
      it "defaults to client_secret_basic and creates a confidential client with a secret" do
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
          "client_secret" => doorkeeper_application.plaintext_secret || doorkeeper_application.secret,
          "client_secret_expires_at" => 0,
          "client_id" => doorkeeper_application.uid,
          "client_id_issued_at" => doorkeeper_application.created_at.to_i,
          "redirect_uris" => redirect_uris,
          "token_endpoint_auth_method" => "client_secret_basic",
          "token_endpoint_auth_methods_supported" => %w[client_secret_basic client_secret_post],
          "response_types" => ["code", "token", "id_token", "id_token token"],
          "grant_types" => %w[authorization_code client_credentials implicit_oidc],
          "scope" => "public",
          "application_type" => "web",
        })
      end
    end

    context "when token_endpoint_auth_method is client_secret_basic" do
      it "creates a confidential client with a secret" do
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
        expect(body["token_endpoint_auth_method"]).to eq("client_secret_basic")
        expect(body["client_secret"]).to be_present
        expect(body["client_secret_expires_at"]).to eq(0)
      end
    end

    context "when token_endpoint_auth_method is client_secret_post" do
      it "creates a confidential client with a secret" do
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
        expect(body["token_endpoint_auth_method"]).to eq("client_secret_post")
        expect(body["client_secret"]).to be_present
        expect(body["client_secret_expires_at"]).to eq(0)
      end
    end

    context "when token_endpoint_auth_method is none" do
      it "creates a public client and omits client_secret from the response" do
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
        expect(body["token_endpoint_auth_method"]).to eq("none")
        expect(body).not_to have_key("client_secret")
        expect(body).not_to have_key("client_secret_expires_at")
      end
    end

    context "when token_endpoint_auth_method is private_key_jwt" do
      it "rejects the request with invalid_client_metadata" do
        post :register, params: {
          client_name: "jwt_client",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "private_key_jwt",
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_client_metadata")
        expect(body["error_description"]).to include("private_key_jwt")
      end
    end

    context "when token_endpoint_auth_method is an unknown value" do
      it "rejects the request with invalid_client_metadata" do
        post :register, params: {
          client_name: "weird_client",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "unknown_value",
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_client_metadata")
        expect(body["error_description"]).to include("unknown_value")
      end
    end

    context "token_endpoint_auth_methods_supported in the response" do
      it "matches the server's configured client_credentials methods" do
        Doorkeeper.configure do
          orm :active_record
          client_credentials :from_basic
          default_scopes :public
        end

        post :register, params: {
          client_name: "cfg_client",
          redirect_uris: redirect_uris,
          scope: "public",
        }

        expect(response.status).to eq 201
        body = JSON.parse(response.body)
        expect(body["token_endpoint_auth_methods_supported"]).to eq(%w[client_secret_basic])
      end
    end

    context "security regression: confidential client cannot bypass credentials" do
      it "is not returned by by_uid_and_secret(uid, nil)" do
        post :register, params: {
          client_name: "secure_client",
          redirect_uris: redirect_uris,
          scope: "public",
        }

        expect(response.status).to eq 201
        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.confidential).to be true

        expect(Doorkeeper::Application.by_uid_and_secret(doorkeeper_application.uid, nil)).to be_nil
      end

      it "is returned by by_uid_and_secret(uid, nil) when token_endpoint_auth_method is none" do
        post :register, params: {
          client_name: "intentionally_public",
          redirect_uris: redirect_uris,
          scope: "public",
          token_endpoint_auth_method: "none",
        }

        expect(response.status).to eq 201
        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.confidential).to be false

        expect(Doorkeeper::Application.by_uid_and_secret(doorkeeper_application.uid, nil)).to eq(doorkeeper_application)
      end
    end

    context "when application_type is native" do
      it "echoes application_type back in the response" do
        post :register, params: {
          client_name: "native_client",
          redirect_uris: redirect_uris,
          scope: "public",
          application_type: "native",
        }

        expect(response.status).to eq 201
        body = JSON.parse(response.body)
        expect(body["application_type"]).to eq("native")
      end
    end

    context "when application_type is not supported" do
      it "rejects the request with invalid_client_metadata" do
        post :register, params: {
          client_name: "weird_client",
          redirect_uris: redirect_uris,
          scope: "public",
          application_type: "service",
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_client_metadata")
        expect(body["error_description"]).to include("application_type 'service'")
      end
    end

    context "when response_types is a subset of the server's supported types" do
      it "echoes the requested response_types back in the response" do
        post :register, params: {
          client_name: "code_only_client",
          redirect_uris: redirect_uris,
          scope: "public",
          response_types: ["code"],
        }

        expect(response.status).to eq 201
        body = JSON.parse(response.body)
        expect(body["response_types"]).to eq(["code"])
      end
    end

    context "when response_types contains an unsupported value" do
      it "rejects the request with invalid_client_metadata" do
        post :register, params: {
          client_name: "bad_response_type_client",
          redirect_uris: redirect_uris,
          scope: "public",
          response_types: %w[code unsupported_type],
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_client_metadata")
        expect(body["error_description"]).to include("unsupported_type")
      end
    end

    context "when grant_types is a subset of the server's supported types" do
      it "echoes the requested grant_types back in the response" do
        post :register, params: {
          client_name: "code_grant_client",
          redirect_uris: redirect_uris,
          scope: "public",
          grant_types: ["authorization_code"],
        }

        expect(response.status).to eq 201
        body = JSON.parse(response.body)
        expect(body["grant_types"]).to eq(["authorization_code"])
      end
    end

    context "when grant_types contains an unsupported value" do
      it "rejects the request with invalid_client_metadata" do
        post :register, params: {
          client_name: "bad_grant_client",
          redirect_uris: redirect_uris,
          scope: "public",
          grant_types: %w[authorization_code password],
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_client_metadata")
        expect(body["error_description"]).to include("password")
      end
    end

    context "when authorize_dynamic_client_registration is configured" do
      let(:valid_register_params) do
        {
          client_name: "auth_client",
          redirect_uris: redirect_uris,
          scope: "public",
        }
      end

      context "when the authorizer returns truthy" do
        before do
          Doorkeeper::OpenidConnect.configure do
            issuer "dummy"
            dynamic_client_registration true
            authorize_dynamic_client_registration { true }
          end
          Rails.application.reload_routes!
        end

        it "allows the request" do
          post :register, params: valid_register_params

          expect(response.status).to eq 201
          expect(Doorkeeper::Application.count).to eq(1)
        end
      end

      context "when the authorizer returns falsy" do
        before do
          Doorkeeper::OpenidConnect.configure do
            issuer "dummy"
            dynamic_client_registration true
            authorize_dynamic_client_registration { false }
          end
          Rails.application.reload_routes!
        end

        it "rejects the request with 401 invalid_token" do
          post :register, params: valid_register_params

          expect(response.status).to eq 401
          expect(Doorkeeper::Application.count).to eq(0)
          expect(response.headers["WWW-Authenticate"]).to include("Bearer")
          expect(response.headers["WWW-Authenticate"]).to include("error=\"invalid_token\"")

          body = JSON.parse(response.body)
          expect(body["error"]).to eq("invalid_token")
        end
      end

      context "when the authorizer reads request context" do
        before do
          Doorkeeper::OpenidConnect.configure do
            issuer "dummy"
            dynamic_client_registration true
            authorize_dynamic_client_registration do
              request.headers["Authorization"] == "Bearer initial-access-token"
            end
          end
          Rails.application.reload_routes!
        end

        it "allows the request when the header matches" do
          request.headers["Authorization"] = "Bearer initial-access-token"
          post :register, params: valid_register_params

          expect(response.status).to eq 201
        end

        it "rejects the request when the header does not match" do
          request.headers["Authorization"] = "Bearer wrong"
          post :register, params: valid_register_params

          expect(response.status).to eq 401
          expect(Doorkeeper::Application.count).to eq(0)
        end
      end
    end

    context "when the requested scope contains values the server does not offer" do
      it "silently drops the unconfigured scopes and persists only the permitted ones" do
        post :register, params: {
          client_name: "scoped_client",
          redirect_uris: redirect_uris,
          scope: "public admin openid",
        }

        expect(response.status).to eq 201
        doorkeeper_application = Doorkeeper::Application.first
        expect(doorkeeper_application.scopes.to_s).to eq("public openid")

        body = JSON.parse(response.body)
        expect(body["scope"]).to eq("public openid")
      end
    end

    context "when every requested scope is unconfigured" do
      it "rejects the registration with invalid_client_metadata" do
        post :register, params: {
          client_name: "greedy_client",
          redirect_uris: redirect_uris,
          scope: "admin superuser",
        }

        expect(response.status).to eq 400
        expect(Doorkeeper::Application.count).to eq(0)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_client_metadata")
        expect(body["error_description"]).to include("no scopes supported")
      end
    end

    context "when the scope parameter is omitted" do
      it "registers the client with an empty scope set without raising" do
        post :register, params: {
          client_name: "no_scope_client",
          redirect_uris: redirect_uris,
        }

        expect(response.status).to eq 201
        expect(Doorkeeper::Application.first.scopes.to_s).to eq("")
      end
    end

    context "when Scopes#allowed is unavailable (doorkeeper < 5.8.1)" do
      before do
        Doorkeeper.configuration.scopes.singleton_class.send(:undef_method, :allowed)
      end

      it "still drops the unconfigured scopes via plain intersection" do
        post :register, params: {
          client_name: "legacy_doorkeeper_client",
          redirect_uris: redirect_uris,
          scope: "public admin openid",
        }

        expect(response.status).to eq 201
        expect(Doorkeeper::Application.first.scopes.to_s).to eq("public openid")

        body = JSON.parse(response.body)
        expect(body["scope"]).to eq("public openid")
      end
    end

    context "with invalid redirect_uris" do
      it "errors and returns errors" do
        post :register, params: {
          client_name: "dummy_client",
          redirect_uris: [
            "http://test.host/registration_success",
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
