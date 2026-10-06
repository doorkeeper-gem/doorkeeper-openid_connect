# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class Engine < ::Rails::Engine
      initializer "doorkeeper.openid_connect.routes" do
        Doorkeeper::OpenidConnect::Rails::Routes.install!
      end

      initializer "doorkeeper.openid_connect.controller_extensions" do |app|
        app.autoloaders.main.on_load("Doorkeeper::AuthorizationsController") do |controller|
          controller.prepend Doorkeeper::OpenidConnect::AuthorizationsExtension
        end

        # Doorkeeper >= 6.0 serves its own RFC 8414 metadata document at
        # /.well-known/oauth-authorization-server; enrich it with the OpenID
        # Connect metadata (see MetadataExtension).
        if Doorkeeper::OpenidConnect.doorkeeper_metadata_endpoint?
          app.autoloaders.main.on_load("Doorkeeper::MetadataController") do |controller|
            controller.prepend Doorkeeper::OpenidConnect::MetadataExtension
          end
        end
      end
    end
  end
end
