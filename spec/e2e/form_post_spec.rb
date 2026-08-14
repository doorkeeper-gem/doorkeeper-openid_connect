# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "response_mode=form_post" do
  it "delivers the code via POST and the exchange still succeeds" do
    client = dashboard_client("formpost")
    run_auth_code_flow(client, response_mode: "form_post", nonce: true)

    expect(page).to have_css("#exchange_result", text: '"id_token"')
  end
end
