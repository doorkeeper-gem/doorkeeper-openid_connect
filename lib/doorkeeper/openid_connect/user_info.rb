module Doorkeeper
  module OpenidConnect
    class UserInfo
      include ActiveModel::Validations

      def initialize(resource_owner, doorkeeper_token)
        @resource_owner = resource_owner
        @scopes = doorkeeper_token.scopes
        @application = doorkeeper_token.application
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
          if @scopes.exists? claim.scope
            [name, claim.generator.call(@resource_owner, @scopes)]
          end
        end.compact.to_h
      end

      def subject
        Doorkeeper::OpenidConnect.configuration.subject.call(@resource_owner, @application).to_s
      end
    end
  end
end
