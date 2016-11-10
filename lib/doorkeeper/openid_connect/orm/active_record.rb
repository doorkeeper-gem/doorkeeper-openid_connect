module Doorkeeper
  module OpenidConnect
    module Orm
      module ActiveRecord
        def initialize_models!
          super
          require 'doorkeeper/openid_connect/orm/active_record/access_grant'
          require 'doorkeeper/openid_connect/orm/active_record/request'

          if Doorkeeper.configuration.active_record_options[:establish_connection]
            [Doorkeeper::OpenidConnect::Request].each do |c|
              c.send :establish_connection, Doorkeeper.configuration.active_record_options[:establish_connection]
            end
          end
        end
      end
    end
  end

  Orm::ActiveRecord.singleton_class.send :prepend, OpenidConnect::Orm::ActiveRecord
end
