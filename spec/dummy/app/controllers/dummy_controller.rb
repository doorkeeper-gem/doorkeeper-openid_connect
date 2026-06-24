# frozen_string_literal: true

class DummyController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :callback

  def index
    @users = User.order(:id)
    @applications = Doorkeeper::Application.order(:id)
  end

  def create_user
    user = User.new(name: params[:name], password: params[:password])

    if user.save
      redirect_to root_path, notice: "User #{user.name} created"
    else
      redirect_to root_path, notice: "User could not be created: #{user.errors.full_messages.to_sentence}"
    end
  end

  def create_application
    application = Doorkeeper::Application.new(
      name: params[:name],
      redirect_uri: params[:redirect_uri].presence || "http://localhost:3000/callback",
      scopes: params[:scopes].presence || "openid",
    )

    if application.save
      redirect_to root_path, notice: "Application created"
    else
      redirect_to root_path, notice: "Application could not be created: #{application.errors.full_messages.to_sentence}"
    end
  end

  def callback
    @params = request.query_parameters
                     .merge(request.request_parameters)
                     .except("controller", "action")
  end
end
