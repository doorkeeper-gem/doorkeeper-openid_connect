# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "Implicit flow (id_token token)" do
  it "returns tokens in the fragment and binds them with at_hash" do
    client = dashboard_client("implicit")
    nonce = start_authorization(client, response_type: "id_token token", nonce: true)

    # The callback page relays the fragment parameters back to the dashboard.
    expect(page).to have_css("#authorize_result", text: '"access_token"')
    expect(page).to have_css("#authorize_result", text: '"id_token"')
    expect(page).to have_no_css("#authorize_result", text: '"code"')

    payload = id_token_payload
    expect(payload["iss"]).to eq("dummy")
    expect(payload["sub"]).to eq(client.user_id)
    expect(payload["aud"]).to eq(client.uid)
    expect(payload["nonce"]).to eq(nonce)
    expect(payload["at_hash"]).to be_present

    # The dashboard fills in the fragment's access token; it must work.
    click_button "Get UserInfo"
    expect(page).to have_css("#userinfo_result", text: %("sub": "#{client.user_id}"))
  end
end
