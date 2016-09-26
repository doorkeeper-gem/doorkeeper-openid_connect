Doorkeeper::OpenidConnect.configure do
  issuer 'dummy'

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  subject do |resource_owner|
    resource_owner.id
  end
end
