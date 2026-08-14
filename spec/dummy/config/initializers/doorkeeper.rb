# frozen_string_literal: true

Doorkeeper.configure do
  optional_scopes :openid

  resource_owner_authenticator do
    # The consent form only replays the OAuth params, so remember the user in
    # the session to survive the POST back to /oauth/authorize.
    session[:current_user] = params[:current_user] if params[:current_user].present?
    if session[:current_user].present?
      User.find(session[:current_user])
    else
      redirect_to("/login")
      nil
    end
  end

  grant_flows %w[authorization_code client_credentials implicit_oidc]

  skip_authorization do
    Rails.env.development? && params[:force_consent].blank?
  end
end
