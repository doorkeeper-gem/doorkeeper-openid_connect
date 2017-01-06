module Doorkeeper
  module OpenidConnect
    class Request
      include DoorkeeperMongodb::Compatible

      include Mongoid::Document

      self.store_in :collection => :openid_requests

      field :access_grant_id, :type => BSON::ObjectId
      field :nonce, :type => String

      belongs_to :access_grant,
        class_name: 'Doorkeeper::AccessGrant',
        inverse_of: :openid_request

      validates :access_grant_id, :nonce, presence: true
    end
  end
end
