module Doorkeeper
  module OpenidConnect
    module Models
      class UserInfo
        include ActiveModel::Validations

        def initialize(resource_owner)
          @resource_owner = resource_owner
        end

        def claims
          {
            sub: subject,
            email: email,
            assignments: assignments
          }.merge(additional_claims)
        end

        def as_json(options = {})
          claims
        end

        private

        def subject
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.subject).to_s
        end

        def email
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.email).to_s
        end

        def assignments
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.assignments)
        end

        def additional_claims
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.additional_claims)
        end
      end
    end
  end
end
