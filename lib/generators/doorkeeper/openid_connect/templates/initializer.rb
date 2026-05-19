# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application, _request|
    # Example implementation:
    # request&.base_url || 'https://example.com'
    "issuer string"
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
    # Used to populate the `auth_time` claim on the ID Token, and as a
    # fallback for `max_age` enforcement when `auth_time_from_session` is
    # not configured.
    #
    # Example implementation:
    # resource_owner.current_sign_in_at
  end

  # Recommended: derive `auth_time` from the current session for `max_age`
  # enforcement. `auth_time_from_resource_owner` returns the same value for
  # every concurrent session of the same user (e.g. PC + smartphone), which
  # can let a stale session satisfy an RP's `max_age` requirement by
  # piggy-backing on a fresh login from another device.
  #
  # The block is executed in the controller's scope and receives the
  # current `session` and `request`. Return value can be a `Time`,
  # `DateTime`, or anything responding to `to_i`. Return `nil` to force
  # reauthentication.
  #
  # auth_time_from_session do |session, _request|
  #   # Example implementation: capture auth_time on the session at login,
  #   # and surface it here.
  #   session[:auth_time]
  # end

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
