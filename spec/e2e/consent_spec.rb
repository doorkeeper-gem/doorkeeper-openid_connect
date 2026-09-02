# frozen_string_literal: true

require_relative "e2e_helper"

# force_consent=1 turns off the development-only skip_authorization, so
# Doorkeeper's real consent screen renders. Capybara resets the session between
# examples, so the remembered current_user never leaks from one to the next.
RSpec.describe "Consent screen" do
  it "issues a code that can be exchanged when the user approves" do
    client = dashboard_client("consent-ok")
    start_authorization(client, force_consent: true)

    expect(page).to have_text("Authorization required")
    expect(page).to have_text(client.name)

    click_button "Authorize"

    expect(page).to have_css("#authorize_result", text: '"code"')
    click_button "Exchange"
    expect(page).to have_css("#exchange_result", text: '"access_token"')
  end

  # The consent form is the one place a nonce can silently go missing: the
  # browser posts back only what the view carried as hidden fields, so a view
  # without a nonce field issues an ID token without one, exactly the trap
  # behind #154. Drive it through a real browser rather than trusting the
  # rendered markup alone.
  it "carries the nonce through the consent screen into the ID token" do
    client = dashboard_client("consent-nonce")
    nonce = start_authorization(client, nonce: true, force_consent: true)

    expect(page).to have_text("Authorization required")
    expect(page).to have_css("input[name='nonce'][value='#{nonce}']", visible: :all)
    click_button "Authorize"

    expect(page).to have_css("#authorize_result", text: '"code"')
    click_button "Exchange"
    expect(page).to have_css("#exchange_result", text: '"id_token"')
    expect(id_token_payload["nonce"]).to eq(nonce)
  end

  it "redirects back with access_denied when the user denies" do
    client = dashboard_client("consent-ng")
    start_authorization(client, force_consent: true)

    expect(page).to have_text("Authorization required")

    click_button "Deny"

    expect(page).to have_css("#authorize_result", text: "access_denied")
    expect(page).to have_no_css("#authorize_result", text: '"code"')
  end
end
