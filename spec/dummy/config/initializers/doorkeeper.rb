# frozen_string_literal: true

Doorkeeper.configure do
  optional_scopes :openid

  resource_owner_authenticator do
    # The consent form only replays the OAuth params, so remember the user in
    # the session to survive the POST back to /oauth/authorize.
    session[:current_user] = params[:current_user] if params[:current_user].present?
    # `find_by`, not `find`: the id arrives from a query parameter, so a stale
    # or made-up value must send the visitor to the login page rather than
    # raise RecordNotFound.
    user = User.find_by(id: session[:current_user]) if session[:current_user].present?

    if user.nil?
      session.delete(:current_user)
      redirect_to("/login")
    end

    user
  end

  grant_flows %w[authorization_code client_credentials implicit_oidc]

  skip_authorization do
    Rails.env.development? && params[:force_consent].blank?
  end
end
