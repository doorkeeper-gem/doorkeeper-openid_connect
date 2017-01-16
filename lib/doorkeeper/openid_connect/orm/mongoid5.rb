module Doorkeeper
  module OpenidConnect
    module Orm
      module Mongoid5
        def self.initialize_models!
          super
          require 'doorkeeper/openid_connect/orm/mongoid5/access_grant'
          require 'doorkeeper/openid_connect/orm/mongoid5/request'
        end
      end
    end
  end

  Orm::Mongoid5.singleton_class.send :prepend, OpenidConnect::Orm::Mongoid5
end
