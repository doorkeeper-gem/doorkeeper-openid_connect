# frozen_string_literal: true

require 'doorkeeper'
require 'active_model'
require 'json/jwt'

require 'doorkeeper/request'
require 'doorkeeper/request/id_token'
require 'doorkeeper/request/id_token_token'
require 'doorkeeper/oauth/id_token_request'
require 'doorkeeper/oauth/id_token_token_request'
require 'doorkeeper/oauth/id_token_response'
require 'doorkeeper/oauth/id_token_token_response'

require 'doorkeeper/openid_connect/claims_builder'
require 'doorkeeper/openid_connect/claims/claim'
require 'doorkeeper/openid_connect/claims/normal_claim'
require 'doorkeeper/openid_connect/config'
require 'doorkeeper/openid_connect/response_types_config'
require 'doorkeeper/openid_connect/engine'
require 'doorkeeper/openid_connect/errors'
require 'doorkeeper/openid_connect/id_token'
require 'doorkeeper/openid_connect/id_token_token'
require 'doorkeeper/openid_connect/user_info'
require 'doorkeeper/openid_connect/response_mode'
require 'doorkeeper/openid_connect/version'

require 'doorkeeper/openid_connect/helpers/controller'

require 'doorkeeper/openid_connect/oauth/authorization/code'
require 'doorkeeper/openid_connect/oauth/authorization_code_request'
require 'doorkeeper/openid_connect/oauth/password_access_token_request'
require 'doorkeeper/openid_connect/oauth/pre_authorization'
require 'doorkeeper/openid_connect/oauth/token_response'

require 'doorkeeper/openid_connect/orm/active_record'

require 'doorkeeper/openid_connect/rails/routes'

module Doorkeeper
  module OpenidConnect
    def self.signing_algorithm
      configuration.signing_algorithm.to_s.upcase.to_sym
    end

    def self.signing_key
      key =
        if %i[HS256 HS384 HS512].include?(signing_algorithm)
          configuration.signing_key
        else
          OpenSSL::PKey.read(configuration.signing_key)
        end
      JSON::JWK.new(key)
    end

    def self.signing_key_normalized
      key = signing_key
      case key[:kty].to_sym
      when :RSA
        key.slice(:kty, :kid, :e, :n)
      when :EC
        key.slice(:kty, :kid, :crv, :x, :y)
      when :oct
        key.slice(:kty, :kid)
      end
    end

    if defined?(::Doorkeeper::GrantFlow)
      Doorkeeper::GrantFlow.register(
        :id_token,
        response_type_matches: 'id_token',
        response_mode_matches: %w[fragment form_post],
        response_type_strategy: Doorkeeper::OpenidConnect::IdToken,
      )

      Doorkeeper::GrantFlow.register(
        'id_token token',
        response_type_matches: 'id_token token',
        response_mode_matches: %w[fragment form_post],
        response_type_strategy: Doorkeeper::OpenidConnect::IdTokenToken,
      )

      Doorkeeper::GrantFlow.register_alias(
        'implicit_oidc', as: ['implicit', 'id_token', 'id_token token']
      )
    else
      # TODO: drop this and corresponding file when we will set minimal
      # required Doorkeeper version to 5.5.
      Doorkeeper::Config.prepend OpenidConnect::ResponseTypeConfig
    end
  end
end
