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
            map_route(:discovery, :discovery_routes)
          end

          routes.scope as: 'oauth' do
            map_route(:discovery, :discovery_well_known_routes)
          end
        end

        private

        def map_route(name, method)
          unless @mapping.skipped?(name)
            mapping = @mapping[name]

            routes.scope controller: mapping[:controllers], as: mapping[:as] do
              send method, mapping
            end
          end
        end

        def userinfo_routes(mapping)
          routes.get :show, path: 'userinfo', as: ''
        end

        def discovery_routes(mapping)
          routes.scope path: 'discovery' do
            routes.get :keys
          end
        end

        def discovery_well_known_routes(mapping)
          routes.scope path: '.well-known' do
            routes.get :provider, path: 'openid-configuration'
            routes.get :webfinger
          end
        end
      end
    end
  end
end
