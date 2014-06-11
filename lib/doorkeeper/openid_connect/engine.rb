module Doorkeeper
  module OpenidConnect
    class Engine < ::Rails::Engine
      puts '************ Doorkeeper::OpenidConnect::Engine'
      initializer 'doorkeeper.openid_connect.routes' do
        Doorkeeper::OpenidConnect::Rails::Routes.install!
      end
    end
  end
end
