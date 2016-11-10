module Doorkeeper
  module OpenidConnect
    class Request < ActiveRecord::Base
      self.table_name = "#{table_name_prefix}oauth_openid_requests#{table_name_suffix}".to_sym

      validates :access_grant_id, :nonce, presence: true
      belongs_to :access_grant,
        class_name: 'Doorkeeper::AccessGrant',
        inverse_of: :openid_request
    end
  end
end
