Doorkeeper.configure do
  resource_owner_authenticator do
    if params[:current_user]
      User.new name: params[:current_user]
    else
      redirect_to('/login')
    end
  end
end
