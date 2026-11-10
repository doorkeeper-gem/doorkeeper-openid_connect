# frozen_string_literal: true

# Assertions on how Doorkeeper::AuthorizationsController answers the client.
#
# Under Doorkeeper's `api_only` mode the controller descends from
# ActionController::API: it answers with JSON where it renders a template or
# redirects otherwise. Each helper accepts both shapes, so the same examples
# run in both modes (set DOORKEEPER_API_ONLY=1 to run them in API mode).
module AuthorizationResponseHelpers
  def api_only?
    Doorkeeper.configuration.api_only
  end

  def expect_authorization_form!
    expect(response).to be_successful
    if api_only?
      expect(json_response).to include("status" => I18n.t("doorkeeper.pre_authorization.status"))
    else
      expect(response).to render_template("doorkeeper/authorizations/new")
    end
  end

  def expect_authorization_error!(status)
    expect(response).to have_http_status(status)
    if api_only?
      expect(json_response).to include("error")
    else
      expect(response).to render_template("doorkeeper/authorizations/error")
    end
  end

  def expect_client_redirect!(uri)
    if api_only?
      expect(json_response).to include("status" => "redirect", "redirect_uri" => uri)
    else
      expect(response).to redirect_to(uri)
    end
  end

  def expect_form_post!
    if api_only?
      expect(json_response).to include("status" => "post")
    else
      expect(response).to render_template(:form_post)
    end
  end

  def expect_successful_callback!
    expect(client_redirect_location).to match(/^#{Regexp.quote application.redirect_uri}\?code=[-\w]+$/)
  end

  def client_redirect_location
    return json_response.fetch("redirect_uri") if api_only?

    expect(response).to be_redirect
    response.location
  end

  def json_response
    expect(response.media_type).to eq "application/json"
    JSON.parse(response.body)
  end
end
