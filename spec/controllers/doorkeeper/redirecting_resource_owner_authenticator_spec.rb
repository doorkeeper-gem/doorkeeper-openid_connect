# frozen_string_literal: true

require "rails_helper"

# Regression coverage for the case where `Doorkeeper.config
# .authenticate_resource_owner` redirects an unauthenticated user instead of
# returning an explicit `nil`.
#
# The most common host-app pattern is:
#
#   resource_owner_authenticator do
#     current_user || redirect_to(new_user_session_url)
#   end
#
# When the user is not signed in, the block's value is whatever `redirect_to`
# returns -- an Integer status on Rails >= 8, the body String on Rails 7 --
# i.e. a *truthy non-model* value, not `nil`. doorkeeper-openid_connect's
# `authenticate_resource_owner!` does `super.tap { |owner| ... }`, so `owner`
# becomes that leaked value and the OIDC param handlers invoke model methods
# on it (`NoMethodError`), followed by a `DoubleRenderError`.
#
# The dummy app's authenticator returns an explicit `nil` after redirecting,
# which is why the rest of the suite never exercises this path.
describe Doorkeeper::AuthorizationsController, type: :controller do
  let(:application) { create :application, scopes: "openid profile" }

  before do
    # Faithfully model the `current_user || redirect_to(...)` pattern for the
    # unauthenticated branch: `redirect_to` is the last expression, so its
    # truthy return value leaks out as the "resource owner".
    leaky_authenticator = proc { redirect_to("/login") }
    allow(Doorkeeper.config)
      .to receive(:authenticate_resource_owner)
      .and_return(leaky_authenticator)
  end

  def authorize!(extra = {})
    get :new, params: {
      response_type: "code",
      client_id: application.uid,
      scope: "openid profile",
      redirect_uri: application.redirect_uri,
    }.merge(extra)
  end

  context "when the resource_owner_authenticator redirects an unauthenticated user" do
    it "prompt=login: falls through to the authenticator's login redirect without raising" do
      expect { authorize!(prompt: "login") }.not_to raise_error
      expect(response).to redirect_to("/login")
    end

    it "max_age: falls through to the authenticator's login redirect without raising" do
      expect { authorize!(max_age: "10") }.not_to raise_error
      expect(response).to redirect_to("/login")
    end

    # prompt=select_account had no `if owner` guard (unlike prompt=login /
    # prompt=consent), so the leaked owner reached the host
    # select_account_for_resource_owner block and a block that touches the
    # owner blew up. With the guard it falls through to the login redirect
    # like the other unauthenticated prompts.
    it "prompt=select_account: falls through to the login redirect without raising" do
      Doorkeeper::OpenidConnect.configure do
        select_account_for_resource_owner do |resource_owner, _return_to|
          redirect_to "/accounts?uid=#{resource_owner.id}"
        end
      end

      expect { authorize!(prompt: "select_account") }.not_to raise_error
      expect(response).to redirect_to("/login")
    end

    # OpenID Connect Core 1.0 §3.1.2.1: with prompt=none and no authenticated
    # End-User the server MUST return a login_required error and MUST NOT show
    # any UI -- so it must NOT bounce to the host app's /login page.
    it "prompt=none: returns the login_required error to the client redirect_uri" do
      expect { authorize!(prompt: "none", state: "somestate") }.not_to raise_error

      expect(response).not_to redirect_to("/login")
      expect(response).to redirect_to(
        build_redirect_uri(
          "error" => "login_required",
          "error_description" => "The authorization server requires end-user authentication",
          "state" => "somestate",
        ),
      )
    end
  end

  def build_redirect_uri(params)
    Doorkeeper::OAuth::Authorization::URIBuilder.uri_with_query(application.redirect_uri, params)
  end
end
