module Doorkeeper
  module OpenidConnect
    module Models
      class UserInfo
        include ActiveModel::Validations

        def initialize(resource_owner)
          @resource_owner = resource_owner
        end

        def claims
          base_claims.merge resource_owner_claims
        end

        def as_json(*_)
          claims
        end

        private

        def base_claims
          {
            sub: subject
          }
        end

        def resource_owner_claims
          Doorkeeper::OpenidConnect.configuration.claims.to_h.map do |name, claim|
            [name, @resource_owner.instance_eval(&claim)]
          end.to_h
        end

        def subject
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.subject).to_s
        end
      end
    end
  end
end
