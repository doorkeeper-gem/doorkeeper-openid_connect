# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "Introspection and revocation" do
  it "introspects an active token, revokes it and sees it die" do
    client = dashboard_client("tokmgmt")
    run_auth_code_flow(client)

    access_token = find("#userinfo_token").value
    expect(access_token).not_to be_empty

    # The token management section authenticates as the selected client.
    find("#tm_client option", text: client.name).select_option

    fill_in "introspect_token", with: access_token
    click_button "Introspect"
    expect(page).to have_css("#introspect_result", text: '"active": true')

    fill_in "revoke_token", with: access_token
    click_button "Revoke"
    expect(page).to have_css("#revoke_result", text: "Revoked")

    click_button "Introspect"
    expect(page).to have_css("#introspect_result", text: '"active": false')

    # The 401 carries its error only in the WWW-Authenticate header.
    click_button "Get UserInfo"
    expect(page).to have_css("#userinfo_result", text: "HTTP 401")
    expect(page).to have_css("#userinfo_result", text: "invalid_token")
  end
end
