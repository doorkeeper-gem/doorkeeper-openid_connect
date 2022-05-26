# frozen_string_literal: true

require 'active_support/lazy_load_hooks'

module Doorkeeper
  module OpenidConnect
    autoload :AccessGrant, "doorkeeper/openid_connect/orm/active_record/access_grant"
    autoload :Request, "doorkeeper/openid_connect/orm/active_record/request"
    
    module Orm
      module ActiveRecord
        def run_hooks
          super
          Doorkeeper::AccessGrant.prepend Doorkeeper::OpenidConnect::AccessGrant
          if Doorkeeper.configuration.active_record_options[:establish_connection]
            [Doorkeeper::OpenidConnect::Request].each do |c|
              c.send :establish_connection, Doorkeeper.configuration.active_record_options[:establish_connection]
            end
          end
        end

        def initialize_models!
          super
          ActiveSupport.on_load(:active_record) do
            require 'doorkeeper/openid_connect/orm/active_record/access_grant'
            require 'doorkeeper/openid_connect/orm/active_record/request'

            Doorkeeper::AccessGrant.prepend Doorkeeper::OpenidConnect::AccessGrant

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
