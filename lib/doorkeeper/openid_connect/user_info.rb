# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class UserInfo
      include ActiveModel::Validations

      def initialize(access_token)
        @access_token = access_token
      end

      def claims
        # NOTE: `sub` is merged last so a custom claim block cannot override
        # the canonical subject identifier (which would defeat pairwise /
        # subject-type guarantees). `resource_owner` is passed through so the
        # access token's owner is resolved once for both the custom claims and
        # `sub`, instead of twice.
        ClaimsBuilder.generate(@access_token, :user_info, resource_owner).merge(
          sub: subject,
        )
      end

      def as_json(*_)
        claims.reject { |_, value| value.nil? || value == "" }
      end

      private

      def subject
        Doorkeeper::OpenidConnect.configuration.subject.call(resource_owner, application).to_s
      end

      def resource_owner
        @resource_owner ||= Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token.call(@access_token)
      end

      def application
        @application ||= @access_token.application
      end
    end
  end
end
