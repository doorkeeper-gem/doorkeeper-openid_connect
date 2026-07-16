Rails.application.routes.draw do
  use_doorkeeper
  use_doorkeeper_openid_connect

  # Second mount under a named scope, exercising multi-namespace support so the
  # discovery document advertises this namespace's own endpoints (see #192).
  scope :admins, as: :admins do
    use_doorkeeper
    use_doorkeeper_openid_connect as: :admins
  end

  root 'dummy#index'

  post 'users' => 'dummy#create_user', as: :users
  post 'applications' => 'dummy#create_application', as: :applications
  match 'callback' => 'dummy#callback', via: %i[get post], as: :callback
end
