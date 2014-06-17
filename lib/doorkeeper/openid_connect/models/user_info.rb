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
          }
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
      end
    end
  end
end
