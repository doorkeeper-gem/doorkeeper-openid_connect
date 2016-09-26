Rails.application.routes.draw do
  use_doorkeeper
  use_doorkeeper_openid_connect
end
