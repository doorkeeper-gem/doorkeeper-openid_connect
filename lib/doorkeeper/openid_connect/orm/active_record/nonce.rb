module Doorkeeper
  module OpenidConnect
    class Nonce < ActiveRecord::Base
      self.table_name = "#{table_name_prefix}oauth_openid_connect_nonces#{table_name_suffix}".to_sym

      validates :access_grant_id, :nonce, presence: true
      belongs_to :access_grant,
        class_name: 'Doorkeeper::AccessGrant',
        inverse_of: :openid_connect_nonce

      def use!
        destroy!
        nonce
      end
    end
  end
end
