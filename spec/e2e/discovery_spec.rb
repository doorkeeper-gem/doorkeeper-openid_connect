# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "Discovery" do
  it "serves the openid-configuration document" do
    visit "/"
    click_button "GET openid-configuration"

    expect(page).to have_css("#disc_config", text: '"issuer": "dummy"')

    config = JSON.parse(find("#disc_config").text)
    expect(config["authorization_endpoint"]).to eq("#{base_url}/oauth/authorize")
    expect(config["token_endpoint"]).to eq("#{base_url}/oauth/token")
    expect(config["userinfo_endpoint"]).to eq("#{base_url}/oauth/userinfo")
    expect(config["jwks_uri"]).to eq("#{base_url}/oauth/discovery/keys")
    expect(config["scopes_supported"]).to include("openid")
    expect(config["response_types_supported"]).to include("code", "id_token", "id_token token")
    expect(config["code_challenge_methods_supported"]).to include("S256")
    expect(config["id_token_signing_alg_values_supported"]).to eq(["RS256"])
    expect(config["subject_types_supported"]).to eq(["public"])
  end

  it "serves the JWKS with the RSA public key only" do
    visit "/"
    click_button "GET jwks (discovery/keys)"

    expect(page).to have_css("#disc_keys", text: '"kty": "RSA"')

    keys = JSON.parse(find("#disc_keys").text)["keys"]
    expect(keys.size).to eq(1)

    key = keys.first
    expect(key["use"]).to eq("sig")
    expect(key["alg"]).to eq("RS256")
    expect(key["kid"]).to be_present
    expect(key["n"]).to be_present
    # Never expose private key material.
    expect(key.keys).not_to include("d", "p", "q")
  end
end
