# frozen_string_literal: true

# Assertions on how Doorkeeper::AuthorizationsController answers the client.
module AuthorizationResponseHelpers
  def expect_authorization_form!
    expect(response).to be_successful
    expect(response).to render_template("doorkeeper/authorizations/new")
  end

  def expect_authorization_error!(status)
    expect(response).to have_http_status(status)
    expect(response).to render_template("doorkeeper/authorizations/error")
  end

  def expect_client_redirect!(uri)
    expect(response).to redirect_to(uri)
  end

  def expect_form_post!
    expect(response).to render_template(:form_post)
  end

  def expect_successful_callback!
    expect(client_redirect_location).to match(/^#{Regexp.quote application.redirect_uri}\?code=[-\w]+$/)
  end

  def client_redirect_location
    expect(response).to be_redirect
    response.location
  end
end
