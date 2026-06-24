# frozen_string_literal: true

require "rails_helper"

# Regression coverage for #192: when the engine is mounted more than once, each
# namespaced mount's discovery document must advertise its own endpoints rather
# than always pointing at the first/default mount.
describe "Discovery across multiple namespaced mounts", type: :request do
  it "advertises the namespaced endpoints for a scoped mount" do
    get "/admins/.well-known/openid-configuration"
    data = JSON.parse(response.body)

    expect(data["authorization_endpoint"]).to end_with("/admins/oauth/authorize")
    expect(data["token_endpoint"]).to end_with("/admins/oauth/token")
    expect(data["revocation_endpoint"]).to end_with("/admins/oauth/revoke")
    expect(data["introspection_endpoint"]).to end_with("/admins/oauth/introspect")
    expect(data["userinfo_endpoint"]).to end_with("/admins/oauth/userinfo")
    expect(data["jwks_uri"]).to end_with("/admins/oauth/discovery/keys")
  end

  it "keeps the default mount advertising un-prefixed endpoints" do
    get "/.well-known/openid-configuration"
    data = JSON.parse(response.body)

    expect(data["authorization_endpoint"]).to end_with("/oauth/authorize")
    expect(data["authorization_endpoint"]).not_to include("/admins/")
    expect(data["userinfo_endpoint"]).to end_with("/oauth/userinfo")
    expect(data["userinfo_endpoint"]).not_to include("/admins/")
  end
end
