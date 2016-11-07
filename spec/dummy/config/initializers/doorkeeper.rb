Doorkeeper.configure do
  resource_owner_authenticator do
    if params[:current_user]
      User.find(params[:current_user])
    else
      redirect_to('/login')
      nil
    end
  end
end
