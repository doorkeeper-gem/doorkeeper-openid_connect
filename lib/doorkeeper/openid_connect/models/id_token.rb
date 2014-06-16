require 'sandal'

module Doorkeeper
  module OpenidConnect
    module Models
      class IdToken
        include ActiveModel::Validations

        def initialize(access_token, resource_owner)
          @access_token = access_token
          @resource_owner = resource_owner
          @issued_at = Time.now
        end

        def claims
          {
            iss: issuer,
            sub: subject,
            aud: audience,
            exp: expiration,
            iat: issued_at
          }
        end

        def as_json(options = {})
          claims
        end

        def as_jws_token
          signer = Sandal::Sig::RS256.new(Doorkeeper::OpenidConnect.configuration.jws_private_key)
          Sandal.encode_token(claims, signer, {
            kid: Doorkeeper::OpenidConnect.configuration.jws_public_key
          })
        end

        private

        def issuer
          Doorkeeper::OpenidConnect.configuration.issuer
        end

        def subject
          subject = @resource_owner.instance_eval(&Doorkeeper::OpenidConnect.configuration.subject)
          subject.to_s
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
      end
    end
  end
end
