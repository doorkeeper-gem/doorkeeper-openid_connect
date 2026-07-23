# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class Engine < ::Rails::Engine
      initializer "doorkeeper.openid_connect.routes" do
        Doorkeeper::OpenidConnect::Rails::Routes.install!
      end

      config.to_prepare do
        Doorkeeper::AuthorizationsController.prepend Doorkeeper::OpenidConnect::AuthorizationsExtension

        # Doorkeeper >= 6.0 serves its own RFC 8414 metadata document at
        # /.well-known/oauth-authorization-server; enrich it with the OpenID
        # Connect metadata (see MetadataExtension).
        if Doorkeeper::OAuth.const_defined?(:MetadataResponse)
          Doorkeeper::MetadataController.prepend Doorkeeper::OpenidConnect::MetadataExtension
        end
      end
    end
  end
end
