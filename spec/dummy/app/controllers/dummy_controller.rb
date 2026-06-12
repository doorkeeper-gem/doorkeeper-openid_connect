# frozen_string_literal: true

class DummyController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :callback

  def index
    @users = User.order(:id)
    @applications = Doorkeeper::Application.order(:id)
  end

  def create_user
    User.create!(name: params[:name], password: params[:password])
    redirect_to root_path, notice: "User #{params[:name]} created"
  end

  def create_application
    Doorkeeper::Application.create!(
      name: params[:name],
      redirect_uri: params[:redirect_uri].presence || "http://localhost:3000/callback",
      scopes: params[:scopes].presence || "openid",
    )
    redirect_to root_path, notice: "Application created"
  end

  def callback
    @params = request.query_parameters
                     .merge(request.request_parameters)
                     .except("controller", "action")
  end
end
