require 'doorkeeper/openid_connect/rails/routes/mapping'
require 'doorkeeper/openid_connect/rails/routes/mapper'

module Doorkeeper
  module OpenidConnect
    module Rails
      class Routes
        module Helper
          def use_doorkeeper_openid_connect(options = {}, &block)
            Doorkeeper::OpenidConnect::Rails::Routes.new(self, &block).generate_routes!(options)
          end
        end

        def self.install!
          ActionDispatch::Routing::Mapper.send :include, Doorkeeper::OpenidConnect::Rails::Routes::Helper
        end

        attr_accessor :routes

        def initialize(routes, &block)
          @routes, @block = routes, block
        end

        def generate_routes!(options)
          @mapping = Mapper.new.map(&@block)
          routes.scope options[:scope] || 'oauth', as: 'oauth' do
            map_route(:userinfo, :userinfo_routes)
          end
        end

        private

        def map_route(name, method)
          unless @mapping.skipped?(name)
            send method, @mapping[name]
          end
        end

        def userinfo_routes(mapping)
          routes.resource(
            :userinfo,
            path: 'userinfo',
            only: [:show], as: mapping[:as],
            controller: mapping[:controllers]
          )
        end
      end
    end
  end
end
