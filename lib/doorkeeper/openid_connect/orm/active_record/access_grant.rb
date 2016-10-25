module Doorkeeper
  module OpenidConnect
    module AccessGrant
      def self.prepended(base)
        base.class_eval do
          has_one :openid_connect_nonce,
            class_name: 'Doorkeeper::OpenidConnect::Nonce',
            inverse_of: :access_grant,
            dependent: :delete
        end
      end
    end
  end

  AccessGrant.send :prepend, OpenidConnect::AccessGrant
end
