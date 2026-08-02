# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::Rails::Routes, type: :routing do
  describe "userinfo" do
    it "maps GET #show" do
      expect(get: "oauth/userinfo").to route_to(
        controller: "doorkeeper/openid_connect/userinfo",
        action: "show",
      )
    end

    it "maps POST #show" do
      expect(post: "oauth/userinfo").to route_to(
        controller: "doorkeeper/openid_connect/userinfo",
        action: "show",
      )
    end
  end

  describe "discovery" do
    it "maps GET #provider" do
      expect(get: ".well-known/openid-configuration").to route_to(
        controller: "doorkeeper/openid_connect/discovery",
        action: "provider",
      )
    end

    it "maps GET #webfinger" do
      expect(get: ".well-known/webfinger").to route_to(
        controller: "doorkeeper/openid_connect/discovery",
        action: "webfinger",
      )
    end

    it "maps GET #keys" do
      expect(get: "oauth/discovery/keys").to route_to(
        controller: "doorkeeper/openid_connect/discovery",
        action: "keys",
      )
    end
  end

  describe "customizing the routes with a block" do
    after { Rails.application.reload_routes! }

    it "maps custom controllers via the controllers option" do
      stub_const("CustomUserinfoController", Class.new(ApplicationController))

      Rails.application.routes.draw do
        use_doorkeeper_openid_connect do
          controllers userinfo: "custom_userinfo"
        end
      end

      expect(get: "oauth/userinfo").to route_to(
        controller: "custom_userinfo",
        action: "show",
      )
    end

    it "does not map controllers listed in skip_controllers" do
      # Keep the discovery routes: a draw ending up with an empty route set
      # never calls Journey's add_route, which is the only place the memoized
      # recognition cache is invalidated (actionpack 8.0.5), so recognition
      # would still see the previously drawn routes.
      Rails.application.routes.draw do
        use_doorkeeper_openid_connect do
          skip_controllers :userinfo
        end
      end

      expect(get: "oauth/userinfo").not_to be_routable
      expect(get: ".well-known/openid-configuration").to route_to(
        controller: "doorkeeper/openid_connect/discovery",
        action: "provider",
      )
    end

    it "renames route helpers via the as option" do
      Rails.application.routes.draw do
        use_doorkeeper_openid_connect do
          as userinfo: :custom_userinfo
        end
      end

      expect(Rails.application.routes.url_helpers.oauth_custom_userinfo_url(host: "example.com"))
        .to eq "http://example.com/oauth/userinfo"
    end
  end

  describe "dynamic_client_registration" do
    it "doesn't map by default" do
      Rails.application.reload_routes!

      expect(post: "oauth/registration").not_to be_routable
    end

    it "maps POST #register" do
      Doorkeeper::OpenidConnect.configure do
        dynamic_client_registration true
      end

      Rails.application.reload_routes!

      expect(post: "oauth/registration").to route_to(
        controller: "doorkeeper/openid_connect/dynamic_client_registration",
        action: "register",
      )
    end
  end
end
