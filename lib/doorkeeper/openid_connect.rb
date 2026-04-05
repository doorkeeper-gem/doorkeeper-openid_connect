# frozen_string_literal: true

require 'doorkeeper'
require 'active_model'
require 'jwt'

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
require 'doorkeeper/openid_connect/engine'
require 'doorkeeper/openid_connect/errors'
require 'doorkeeper/openid_connect/id_token'
require 'doorkeeper/openid_connect/id_token_token'
require 'doorkeeper/openid_connect/user_info'
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
      algo = if configuration.signing_algorithm.respond_to?(:call)
        configuration.signing_algorithm.call
      else
        configuration.signing_algorithm
      end
      algo.to_s.upcase.to_sym
    end

    def self.signing_key
      key_value = if configuration.signing_key.respond_to?(:call)
        configuration.signing_key.call
      else
        configuration.signing_key
      end

      key =
        if %i[HS256 HS384 HS512].include?(signing_algorithm)
          key_value
        else
          OpenSSL::PKey.read(key_value)
        end
      ::JWT::JWK.new(key, { kid_generator: ::JWT::JWK::Thumbprint })
    end

    def self.signing_key_normalized
      signing_key.export
    end

    # Resolves the issuer value from the configuration, handling both
    # static values and callable blocks with backward-compatible arity checks.
    #
    # @param resource_owner [Object, nil] the authenticated user (nil in discovery context)
    # @param application [Object, nil] the OAuth application (nil in discovery context)
    # @param request [ActionDispatch::Request, nil] the current request (nil in token context)
    # @return [String] the issuer string
    def self.resolve_issuer(resource_owner: nil, application: nil, request: nil)
      issuer = configuration.issuer
      return issuer.to_s unless issuer.respond_to?(:call)

      case issuer.arity
      when 0
        issuer.call
      when 1
        issuer.call(request || resource_owner)
      when 2
        issuer.call(resource_owner, application)
      else
        issuer.call(resource_owner, application, request)
      end.to_s
    end

    Doorkeeper::GrantFlow.register(
      :id_token,
      response_type_matches: 'id_token',
      response_mode_matches: %w[fragment form_post],
      response_type_strategy: Doorkeeper::Request::IdToken,
    )

    Doorkeeper::GrantFlow.register(
      'id_token token',
      response_type_matches: 'id_token token',
      response_mode_matches: %w[fragment form_post],
      response_type_strategy: Doorkeeper::Request::IdTokenToken,
    )

    Doorkeeper::GrantFlow.register_alias(
      'implicit_oidc', as: ['implicit', 'id_token', 'id_token token']
    )
  end
end
