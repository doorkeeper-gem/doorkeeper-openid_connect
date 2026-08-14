# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "Authorization code flow" do
  it "issues a code, exchanges it for tokens and serves userinfo" do
    client = dashboard_client("authcode")
    nonce = run_auth_code_flow(client, nonce: true)

    payload = id_token_payload
    expect(payload["iss"]).to eq("dummy")
    expect(payload["sub"]).to eq(client.user_id)
    expect(payload["aud"]).to eq(client.uid)
    expect(payload["nonce"]).to eq(nonce)
    expect(payload["exp"]).to be_a(Integer)
    expect(payload["iat"]).to be_a(Integer)
    expect(payload["exp"]).to be > payload["iat"]
    # Without an explicit `response:` option a claim is userinfo-only, so the
    # ID token carries just the ones targeted at it.
    expect(payload).not_to have_key("name")
    expect(payload).to have_key("id_token_response")
    expect(payload).to have_key("both_responses")
    expect(payload).not_to have_key("user_info_response")

    click_button "Get UserInfo"
    expect(page).to have_css("#userinfo_result", text: %("sub": "#{client.user_id}"))
    # `name` defaults to the profile scope, which this client was not granted.
    expect(page).to have_no_css("#userinfo_result", text: '"name"')
    expect(page).to have_css("#userinfo_result", text: '"variable_name": "openid-name"')
    expect(page).to have_css("#userinfo_result", text: '"user_info_response": "user_info"')
    expect(page).to have_css("#userinfo_result", text: '"both_responses": "both"')
    expect(page).to have_no_css("#userinfo_result", text: '"id_token_response"')
  end

  it "rejects an already used authorization code" do
    client = dashboard_client("authcode-reuse")
    run_auth_code_flow(client)

    # The first exchange consumed the code; replaying it must fail.
    click_button "Exchange"
    expect(page).to have_css("#exchange_result", text: "invalid_grant")
  end
end
