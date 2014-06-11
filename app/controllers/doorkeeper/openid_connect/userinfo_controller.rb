module Doorkeeper
  module OpenidConnect
    class UserinfoController < ::Doorkeeper::ApplicationController
      def show
        render text: 'hello world'
      end
    end
  end
end
