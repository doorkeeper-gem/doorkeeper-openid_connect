module Doorkeeper
  module OpenidConnect
    class AccessGrant
      has_one :openid_request,
        :class_name => 'Doorkeeper::OpenidConnect::Request',
        :inverse_of =>:access_grant,
        :dependent => :delete
    end
  end
end
