require 'doorkeeper'
require 'json/jwt'

require 'doorkeeper/openid_connect/claims_builder'
require 'doorkeeper/openid_connect/config'
require 'doorkeeper/openid_connect/engine'
require 'doorkeeper/openid_connect/version'

require 'doorkeeper/openid_connect/helpers/controller'

require 'doorkeeper/openid_connect/models/id_token'
require 'doorkeeper/openid_connect/models/user_info'
require 'doorkeeper/openid_connect/models/claims/claim'
require 'doorkeeper/openid_connect/models/claims/normal_claim'

require 'doorkeeper/openid_connect/oauth/authorization/code'
require 'doorkeeper/openid_connect/oauth/authorization_code_request'
require 'doorkeeper/openid_connect/oauth/password_access_token_request'
require 'doorkeeper/openid_connect/oauth/pre_authorization'
require 'doorkeeper/openid_connect/oauth/token_response'

require 'doorkeeper/openid_connect/orm/active_record'

require 'doorkeeper/openid_connect/rails/routes'

module Doorkeeper
  singleton_class.send :prepend, OpenidConnect::DoorkeeperConfiguration

  module OpenidConnect
    # TODO: make this configurable
    SIGNING_ALGORITHM = 'RS256'

    def self.signing_key
      JSON::JWK.new(OpenSSL::PKey.read(configuration.jws_private_key))
    end
  end
end
