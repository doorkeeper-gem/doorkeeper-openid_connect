# frozen_string_literal: true

require "rails_helper"

# Pins the token response of a password grant that runs without client
# authentication. `skip_client_authentication_for_password_grant` lets such a
# request succeed with no client at all, so the access token it commits has no
# application and its ID Token cannot source the REQUIRED `aud` claim. The
# grant presets an ID Token before the response is rendered, which used to
# defeat the application guard in `TokenResponse#body` and surface as a 500
# (`MissingRequiredClaim`) after the token row was already committed.
describe "Password grant token requests", type: :request do
  let!(:user) { create :user }

  before do
    Doorkeeper.configure do
      optional_scopes :openid

      grant_flows %w[password]
      skip_client_authentication_for_password_grant true

      resource_owner_from_credentials do
        User.find_by(id: params[:user_id])
      end
    end
  end

  context "with the openid scope and no client authentication" do
    it "answers with a token response that omits id_token" do
      post "/oauth/token", params: { grant_type: "password", scope: "openid", user_id: user.id }

      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)
      expect(data).not_to have_key("id_token")
      expect(data["access_token"]).to be_present
      expect(data["scope"]).to eq "openid"

      expect(Doorkeeper::AccessToken.last.application_id).to be_nil
    end
  end

  context "with the openid scope and an authenticated client" do
    let(:application) { create :application }

    it "answers with an ID Token" do
      post "/oauth/token", params: {
        grant_type: "password",
        scope: "openid",
        user_id: user.id,
        client_id: application.uid,
        client_secret: application.plaintext_secret,
      }

      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)
      expect(data["id_token"]).to be_present
      expect(Doorkeeper::AccessToken.last.application_id).to eq application.id
    end
  end
end
