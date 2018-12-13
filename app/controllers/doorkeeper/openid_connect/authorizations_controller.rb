module Doorkeeper
  module OpenidConnect
    class AuthorizationsController < Doorkeeper::AuthorizationsController

      def new
        super
      end

      def create
        super
      end

      # consider response_mode parameter
      private def redirect_or_render(auth)
        return super if params[:response_mode] != :form_post.to_s || !auth.respond_to?(:form_response)
        response.headers['Content-Type'] = 'text/html;charset=UTF-8'
        response.headers['Cache-Control'] = 'no-cache,no-store'
        response.headers['Pragma'] = 'no-cache'
        render body: auth.form_response
      end
    end
  end
end