module Doorkeeper
  module OpenidConnect
    class UserInfo
      include ActiveModel::Validations

      def initialize(access_token)
        @access_token = access_token
      end

      def claims
        base_claims.merge resource_owner_claims
      end

      def as_json(*_)
        claims.reject { |_, value| value.nil? || value == '' }
      end

      private

      def base_claims
        {
          sub: subject
        }
      end

      def resource_owner_claims
        Doorkeeper::OpenidConnect.configuration.claims.to_h.map do |name, claim|
          if scopes.exists? claim.scope
            [name, claim.generator.call(resource_owner, scopes, @access_token)]
          end
        end.compact.to_h
      end

      def subject
        Doorkeeper::OpenidConnect.configuration.subject.call(resource_owner, application).to_s
      end

      def resource_owner
        @resource_owner ||= Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token.call(@access_token)
      end

      def application
        @application ||= @access_token.application
      end

      def scopes
        @scopes ||= @access_token.scopes
      end
    end
  end
end
