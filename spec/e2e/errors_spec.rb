# frozen_string_literal: true

require_relative "e2e_helper"

RSpec.describe "Authorization error responses" do
  it "refuses a redirect_uri that does not match the client" do
    client = dashboard_client("err-redirect")

    authorize(
      client_id: client.uid,
      redirect_uri: "http://evil.example/cb",
      response_type: "code",
      scope: "openid",
      current_user: client.user_id,
    )

    # The error must be rendered here, never redirected to the evil host.
    expect(current_host).to eq(URI.parse(base_url).host)
    expect(page).to have_text(/redirect uri/i)
  end

  it "rejects an unknown client_id" do
    client = dashboard_client("err-client")

    authorize(
      client_id: "this-client-does-not-exist",
      redirect_uri: "#{base_url}/callback",
      response_type: "code",
      scope: "openid",
      current_user: client.user_id,
    )

    expect(current_host).to eq(URI.parse(base_url).host)
    expect(page).to have_text(/client/i)
  end

  def authorize(params)
    visit "/oauth/authorize?#{params.to_query}"
  end

  def current_host
    URI.parse(page.current_url).host
  end
end
