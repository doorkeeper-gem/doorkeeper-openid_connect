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

        def as_json(options = {})
          claims
        end

        private

        def base_claims
          {
            sub: subject
          }
        end

        def resource_owner_claims
          Doorkeeper::OpenidConnect.configuration.claims.to_h.map do |claim_name, claim_value|
            [claim_name, @resource_owner.instance_eval(&claim_value)]
          end.to_h
        end

        def subject
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.subject).to_s
        end
      end
    end
  end
end
