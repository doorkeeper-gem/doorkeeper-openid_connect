module Doorkeeper
  module OpenidConnect
    module Models
      class IdToken
        include ActiveModel::Validations

        attr_reader :subject

        def initialize(subject)
          @subject = subject
        end

        def iss
          Doorkeeper::OpenidConnect.configuration.issuer
        end
      end
    end
  end
end
