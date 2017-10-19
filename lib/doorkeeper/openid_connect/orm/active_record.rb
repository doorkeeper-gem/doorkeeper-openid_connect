require 'active_support/lazy_load_hooks'

module Doorkeeper
  module OpenidConnect
    module Orm
      module ActiveRecord
        def initialize_models!
          super
          ActiveSupport.on_load(:active_record) do
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
  end

  Orm::ActiveRecord.singleton_class.send :prepend, OpenidConnect::Orm::ActiveRecord
end
