# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "PKCE (S256)" do
  it "exchanges the code when the verifier matches" do
    client = dashboard_client("pkce")
    run_auth_code_flow(client, pkce: true)

    expect(page).to have_css("#exchange_result", text: '"access_token"')
  end

  it "rejects the exchange with a missing or wrong verifier" do
    client = dashboard_client("pkce-neg")
    start_authorization(client, pkce: true)
    expect(page).to have_css("#authorize_result", text: '"code"')

    # Missing verifier → invalid_request (a required parameter is absent).
    fill_in "tok_code_verifier", with: ""
    click_button "Exchange"
    expect(page).to have_css("#exchange_result", text: "invalid_request")

    # Wrong verifier → invalid_grant (it does not match the challenge).
    fill_in "tok_code_verifier", with: "wrong-verifier-wrong-verifier-wrong-verifier"
    click_button "Exchange"
    expect(page).to have_css("#exchange_result", text: "invalid_grant")
  end
end
