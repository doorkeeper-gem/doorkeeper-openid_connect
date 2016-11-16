Doorkeeper::OpenidConnect.configure do
  issuer 'issuer string'

  jws_private_key <<-EOL
-----BEGIN RSA PRIVATE KEY-----
....
-----END RSA PRIVATE KEY-----
EOL

  jws_public_key <<-EOL
-----BEGIN RSA PUBLIC KEY-----
....
-----END RSA PUBLIC KEY-----
EOL
 
  signing_algorithm 'RS256'
git@github.com:doorkeeper-gem/doorkeeper-openid_connect.git
....

  resource_owner_from_access_token do |access_token|
    # Example implementation:
    # User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    # Example implementation:
    # resource_owner.current_sign_in_at
  end

  reauthenticate_resource_owner do |resource_owner|
    # Example implementation:
    # store_location_for resource_owner, request.fullpath
    # sign_out resource_owner
    # redirect_to new_user_session_url
  end

  subject do |resource_owner|
    # Example implementation:
    # resource_owner.key
  end

  # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
  # expiration 600

  # Example claims:
  # claims do
  #   normal_claim :_foo_ do |resource_owner|
  #     resource_owner.foo
  #   end

  #   normal_claim :_bar_ do |resource_owner|
  #     resource_owner.bar
  #   end
  # end
end
