# frozen_string_literal: true

class DummyController < ApplicationController
  def index
    redirect_to "/.well-known/openid-configuration", status: :found
  end
end
