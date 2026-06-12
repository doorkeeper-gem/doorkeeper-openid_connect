Rails.application.routes.draw do
  use_doorkeeper
  use_doorkeeper_openid_connect

  root 'dummy#index'

  post 'users' => 'dummy#create_user', as: :users
  post 'applications' => 'dummy#create_application', as: :applications
  match 'callback' => 'dummy#callback', via: %i[get post], as: :callback
end
