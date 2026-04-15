# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do
  issuer do |resource_owner, application, request|
    # Example implementation:
    # request&.base_url || 'https://example.com'
    'issuer string'
  end

  signing_key <<~KEY
    -----BEGIN RSA PRIVATE KEY-----
    ....
    -----END RSA PRIVATE KEY-----
  KEY

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    # Example implementation:
    # User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    # Example implementation:
    # resource_owner.current_sign_in_at
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # sign_out resource_owner
    # redirect_to new_user_session_url
  end

  select_account_for_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # redirect_to account_select_url
  end

  subject do |resource_owner, application|
    # Example implementation:
    # resource_owner.id

    # or if you need pairwise subject identifier, implement like below:
    # Digest::SHA256.hexdigest("#{resource_owner.id}#{URI.parse(application.redirect_uri).host}#{'your_secret_salt'}")
  end

  # Protocol to use when generating URIs for the discovery endpoint,
  # for example if you also use HTTPS in development
  # protocol do
  #   :https
  # end

  # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
  # expiration 600

  # Enable dynamic client registration (default false)
  # dynamic_client_registration true

  # You can use your own model class if you need to extend (or even override) the default
  # Doorkeeper::OpenidConnect::Request model (e.g. to use a different database connection).
  #
  # By default Doorkeeper OpenID Connect uses:
  #
  # open_id_request_class "Doorkeeper::OpenidConnect::Request"
  #
  # Don't forget to include the OpenID Connect ORM mixin into your custom model:
  #
  #   * ::Doorkeeper::OpenidConnect::Orm::ActiveRecord::Mixins::OpenidRequest
  #
  # For example:
  #
  # open_id_request_class "MyOpenidRequest"
  #
  # class MyOpenidRequest < ApplicationRecord
  #   include ::Doorkeeper::OpenidConnect::Orm::ActiveRecord::Mixins::OpenidRequest
  # end

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
