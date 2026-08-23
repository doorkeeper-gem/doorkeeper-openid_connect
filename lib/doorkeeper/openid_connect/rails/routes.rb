# frozen_string_literal: true

require "doorkeeper/openid_connect/rails/routes/mapping"
require "doorkeeper/openid_connect/rails/routes/mapper"

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
          ActionDispatch::Routing::Mapper.include Doorkeeper::OpenidConnect::Rails::Routes::Helper
        end

        attr_accessor :routes

        def initialize(routes, &block)
          @routes = routes
          @block = block
        end

        def generate_routes!(options)
          @mapping = Mapper.new.map(&@block)

          routes.scope options[:scope] || "oauth", as: "oauth" do
            map_oauth_routes
          end

          routes.scope(**well_known_scope(options)) do
            map_route(:discovery, :discovery_well_known_routes)
          end
        end

        private

        def map_oauth_routes
          map_route(:userinfo, :userinfo_routes)
          map_route(:discovery, :discovery_routes)
          return unless ::Doorkeeper::OpenidConnect.configuration.dynamic_client_registration

          map_route(:dynamic_client_registration, :dynamic_client_registration_routes)
        end

        def well_known_scope(options)
          prefix = route_helper_prefix(options)
          scope = { as: "oauth" }
          # When the engine is mounted under a named scope (e.g.
          # `scope :users, as: :users`), Doorkeeper's and this engine's URL
          # helpers are generated with that prefix (`users_oauth_*`). Pass the
          # prefix down to the discovery controller via a route default so it can
          # resolve the correct namespaced helpers for the published endpoints.
          scope[:defaults] = { route_helper_prefix: prefix } if prefix.present?
          scope
        end

        def route_helper_prefix(options)
          name = options[:as]
          name.present? ? "#{name}_" : ""
        end

        def map_route(name, method)
          return if @mapping.skipped?(name)

          mapping = @mapping[name]

          routes.scope controller: mapping[:controllers], as: mapping[:as] do
            send method
          end
        end

        def userinfo_routes
          routes.get :show, path: "userinfo", as: ""
          routes.post :show, path: "userinfo", as: nil
        end

        def discovery_routes
          routes.scope path: "discovery" do
            routes.get :keys
          end
        end

        def discovery_well_known_routes
          routes.scope path: ".well-known" do
            routes.get :provider, path: "openid-configuration"
            routes.get :provider, path: "oauth-authorization-server"
            routes.get :webfinger
          end
        end

        def dynamic_client_registration_routes
          routes.post :register, path: "registration", as: ""
        end
      end
    end
  end
end
