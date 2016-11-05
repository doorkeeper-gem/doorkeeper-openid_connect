module Doorkeeper
  module OpenidConnect
    module Models
      class IdToken
        include ActiveModel::Validations

        attr_reader :nonce

        def initialize(access_token, nonce = nil)
          @access_token = access_token
          @nonce = nonce
          @resource_owner = access_token.instance_eval(&Doorkeeper::OpenidConnect.configuration.resource_owner_from_access_token)
          @issued_at = Time.now
        end

        def claims
          {
            iss: issuer,
            sub: subject,
            aud: audience,
            exp: expiration,
            iat: issued_at,
            nonce: nonce,
            auth_time: auth_time,
          }
        end

        def as_json(*_)
          claims.reject { |_, value| value.blank? }
        end

        def as_jws_token
          JSON::JWT.new(as_json).sign(Doorkeeper::OpenidConnect.signing_key).to_s
        end

        private

        def issuer
          Doorkeeper::OpenidConnect.configuration.issuer
        end

        def subject
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.subject).to_s
        end

        def audience
          @access_token.application.uid
        end

        def expiration
          (@issued_at.utc + Doorkeeper::OpenidConnect.configuration.expiration).to_i
        end

        def issued_at
          @issued_at.utc.to_i
        end

        def auth_time
          @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.auth_time_from_resource_owner).try(:to_i)
        end
      end
    end
  end
end
