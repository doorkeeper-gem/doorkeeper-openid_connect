# frozen_string_literal: true

# Drives the dummy application's dashboard — spec/dummy/app/views/dummy/index.html.erb,
# the browser stand-in for the README's curl commands — so the specs read as
# flows rather than as selectors.
module Dashboard
  # A user and the OAuth application it authorizes, both created through the
  # dashboard's own forms.
  Client = Struct.new(:user_id, :user_name, :name, :uid, :secret, keyword_init: true)

  # Creates a user and an application whose names are unique to this example,
  # so a run never depends on what another example left behind.
  def dashboard_client(prefix)
    suffix = SecureRandom.hex(4)
    user_name = "#{prefix}-user-#{suffix}"
    app_name = "#{prefix}-app-#{suffix}"

    Client.new(
      user_id: create_user(user_name),
      user_name: user_name,
      name: app_name,
      **create_application(app_name),
    )
  end

  # Creates a user through the dashboard form and returns its id.
  def create_user(name)
    visit "/"
    within "form[action='/users']" do
      fill_in "name", with: name
      click_button "Create user"
    end

    find("#users tr", text: name).first("td").text.strip
  end

  # Creates an application through the dashboard form and returns its
  # credentials, read back from the client <select> the dashboard renders.
  def create_application(name)
    visit "/"
    within "form[action='/applications']" do
      fill_in "name", with: name
      click_button "Create application"
    end

    option = find("#auth_client option", text: name)
    { uid: option["data-uid"], secret: option["data-secret"] }
  end

  # Fills in the dashboard's authorization form and sends the request.
  # Returns the nonce the dashboard generated, when one was asked for.
  def start_authorization(client, response_type: "code", response_mode: nil,
                          nonce: false, pkce: false, force_consent: false)
    visit "/"
    find("#current_user option[value='#{client.user_id}']").select_option
    find("#auth_client option", text: client.name).select_option
    select response_type, from: "response_type"
    select response_mode, from: "response_mode" if response_mode

    generated_nonce = nil
    if nonce
      check "nonce_enabled"
      generated_nonce = find("#nonce").value
      expect(generated_nonce).not_to be_empty
    end

    if pkce
      check "pkce_enabled"
      # The verifier and challenge are generated asynchronously.
      expect(page).to have_css("#code_verifier", text: /\S/)
    end

    check "force_consent" if force_consent

    click_button "Authorize →"
    generated_nonce
  end

  # Runs the whole authorization code flow: authorize, bounce back through
  # /callback, exchange the code. Leaves the browser on the dashboard with the
  # ID token decoded and the access token filled in for UserInfo.
  def run_auth_code_flow(client, **options)
    nonce = start_authorization(client, **options)
    expect(page).to have_css("#authorize_result", text: '"code"')

    click_button "Exchange"
    expect(page).to have_css("#exchange_result", text: '"access_token"')
    expect(page).to have_css("#exchange_result", text: '"id_token"')

    nonce
  end

  # The decoded ID token payload the dashboard renders.
  def id_token_payload
    expect(page).to have_css("#idtoken_payload", text: '"iss"')
    JSON.parse(find("#idtoken_payload").text)
  end

  # The base URL of the application under test, which the dashboard's own
  # links and the discovery document are expected to agree with.
  def base_url
    page.server.base_url
  end
end
