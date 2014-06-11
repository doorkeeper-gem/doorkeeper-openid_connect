module Doorkeeper
  module OpenidConnect
    class Engine < ::Rails::Engine
      initializer 'doorkeeper.openid_connect.routes' do
        Doorkeeper::OpenidConnect::Rails::Routes.install!
      end
    end
  end
end
