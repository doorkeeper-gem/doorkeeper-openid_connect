# frozen_string_literal: true

require "rails_helper"

# Doorkeeper's RFC 8414 metadata endpoint only exists on Doorkeeper >= 6.0;
# MetadataExtension (prepended by the engine) enriches it with the OpenID
# Connect metadata so it agrees with the gem's own discovery document. Guarded
# through the same predicate the engine uses, so this file cannot start
# referencing Doorkeeper::MetadataController on a version that lacks it.
if Doorkeeper::OpenidConnect.doorkeeper_metadata_endpoint?
  describe Doorkeeper::MetadataController, type: :controller do
    describe "#show" do
      it "enriches the document with the OpenID Connect metadata" do
        get :show

        data = JSON.parse(response.body)

        expect(data["issuer"]).to eq "dummy"
        expect(data["userinfo_endpoint"]).to eq "http://test.host/oauth/userinfo"
        expect(data["jwks_uri"]).to eq "http://test.host/oauth/discovery/keys"
        expect(data["subject_types_supported"]).to eq ["public"]
        expect(data["id_token_signing_alg_values_supported"]).to eq ["RS256"]
        expect(data["claim_types_supported"]).to eq ["normal"]
        expect(data["claims_supported"]).to include("iss", "sub", "aud", "exp", "iat")
      end

      it "keeps the Doorkeeper-derived fields of the core document" do
        get :show

        data = JSON.parse(response.body)

        expect(data["authorization_endpoint"]).to eq "http://test.host/oauth/authorize"
        expect(data["token_endpoint"]).to eq "http://test.host/oauth/token"
        expect(data["token_endpoint_auth_methods_supported"]).to include("client_secret_basic")
      end

      it "lets an app-configured custom_metadata override the injected OIDC fields" do
        config = Doorkeeper.configuration
        allow(Doorkeeper).to receive(:configuration).and_return(config)
        allow(config).to receive(:custom_metadata)
          .and_return(claims_supported: %w[custom], service_documentation: "https://docs.example.com")

        get :show

        data = JSON.parse(response.body)

        expect(data["claims_supported"]).to eq %w[custom]
        expect(data["service_documentation"]).to eq "https://docs.example.com"
        expect(data["jwks_uri"]).to eq "http://test.host/oauth/discovery/keys"
      end

      it "serves the plain Doorkeeper document when OpenID Connect is not configured" do
        allow(Doorkeeper::OpenidConnect).to receive(:configured?).and_return(false)

        get :show

        data = JSON.parse(response.body)

        expect(data["issuer"]).to eq "http://test.host"
        expect(data["userinfo_endpoint"]).to be_nil
        expect(data).not_to have_key("jwks_uri")
      end

      it "serves the plain Doorkeeper document when the gem's routes are not mounted" do
        allow(controller).to receive(:endpoint_defined?).and_return(false)

        get :show

        expect(response).to have_http_status(:ok)

        data = JSON.parse(response.body)

        expect(data["issuer"]).to eq "http://test.host"
        expect(data["userinfo_endpoint"]).to be_nil
        expect(data).not_to have_key("jwks_uri")
      end

      it "omits the registration_endpoint when dynamic client registration is enabled but its route is not drawn" do
        # The registration route is drawn from the configuration active when
        # the app's routes were loaded; enabling the option afterwards leaves
        # the route (and its URL helper) absent.
        Rails.application.reload_routes!

        # `reload_routes!` can defer the actual redraw until the first routing
        # access (Rails' lazy route loading), which would otherwise happen
        # inside `get :show` — after the configure block below has enabled
        # dynamic_client_registration, drawing the very route this example
        # needs absent. Recognizing a path forces the redraw now and asserts
        # the premise, making the example deterministic across run orders.
        expect { Rails.application.routes.recognize_path("/oauth/registration", method: :post) }
          .to raise_error(ActionController::RoutingError)

        Doorkeeper::OpenidConnect.configure do
          issuer "dummy"
          dynamic_client_registration true
        end

        get :show

        expect(response).to have_http_status(:ok)

        data = JSON.parse(response.body)

        expect(data).not_to have_key("registration_endpoint")
        expect(data["jwks_uri"]).to eq "http://test.host/oauth/discovery/keys"
      end
    end
  end
end
