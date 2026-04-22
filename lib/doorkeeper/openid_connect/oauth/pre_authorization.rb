# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module PreAuthorization
        def self.prepended(base)
          base.validate :nonce, error: Doorkeeper::Errors::InvalidRequest
        end

        attr_reader :nonce

        def initialize(server, attrs = {}, resource_owner = nil)
          super
          @nonce = attrs[:nonce]
        end

        # NOTE: Auto get default response_mode of specified response_type if response_mode is not
        #   yet present. We can delete this method after Doorkeeper's minimize version support it.
        def response_on_fragment?
          return response_mode == 'fragment' if response_mode.present?

          grant_flow = server.authorization_response_flows.detect do |flow|
            flow.matches_response_type?(response_type)
          end

          grant_flow&.default_response_mode == 'fragment'
        end

        private

        # Per OpenID Connect Core 1.0 Section 3.2.2.1, nonce is REQUIRED for the
        # implicit flow (id_token and id_token token response types).
        def validate_nonce
          return true unless openid_implicit_flow?

          if nonce.blank?
            @missing_param = :nonce
            return false
          end

          true
        end

        def openid_implicit_flow?
          scopes.include?('openid') &&
            response_type.to_s.split(' ').include?('id_token')
        end
      end
    end
  end

  OAuth::PreAuthorization.prepend OpenidConnect::OAuth::PreAuthorization
end
