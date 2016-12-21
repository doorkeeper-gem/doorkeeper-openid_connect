module Doorkeeper
  module OpenidConnect
    class UserInfo
      include ActiveModel::Validations

      def initialize(resource_owner, scopes)
        @resource_owner = resource_owner
        @scopes = scopes
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
            [name, @resource_owner.instance_eval(&claim.generator)]
          end
        end.compact.to_h
      end

      def subject
        @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.subject).to_s
      end
    end
  end
end
