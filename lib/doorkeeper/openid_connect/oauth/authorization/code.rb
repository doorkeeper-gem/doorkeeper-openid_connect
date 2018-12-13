module Doorkeeper
  module OpenidConnect
    module OAuth
      module Authorization
        module Code
          def issue_token
            super.tap do |access_grant|
              if pre_auth.nonce.present?
                # write to request record into table
                ::Doorkeeper::OpenidConnect::Request.create!(
                  access_grant: access_grant,
                  nonce: pre_auth.nonce
                )
              end
            end
          end
        end
      end
    end
  end

  OAuth::Authorization::Code.send :prepend, OpenidConnect::OAuth::Authorization::Code
end
