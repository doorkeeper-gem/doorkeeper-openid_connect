module Doorkeeper
  module OAuth
    class CodeIdTokenResponse < BaseResponse
      include OAuth::Helpers

      attr_accessor :pre_auth, :auth, :auth_token, :id_token

      def initialize(pre_auth, auth, auth_token, id_token)
        @pre_auth = pre_auth
        @auth = auth
        @auth_token = auth_token
        @id_token = id_token
      end

      def redirectable?
        true
      end

      def redirect_uri
        Authorization::URIBuilder.uri_with_fragment(
          pre_auth.redirect_uri,
          code: auth.token.token,
          expires_in: auth_token.token.expires_in_seconds,
          state: pre_auth.state,
          id_token: id_token.as_jws_token
        )
      end

      def form_response
        response_form(pre_auth.redirect_uri,
                      auth.token.token,
                      auth_token.token.expires_in_seconds,
                      pre_auth.state,
                      id_token.as_jws_token)
      end

      def response_form(redirect_uri, code, expires_in, state, id_token)
        <<~EOT.html_safe
          <html>
            <head>
              <title>Submit This Form</title>
            </head>
            <body onload="javascript:document.forms[0].submit()">
              <form method="post" action="#{redirect_uri}">
                <input type="hidden" name="state" value="#{state}"/>
                <input type="hidden" name="code" value="#{code}"/>
                <input type="hidden" name="id_token" value="#{id_token}"/>
                <input type="hidden" name="expires_in" value="#{expires_in}"/>
              </form>
            </body>
          </html>
        EOT
      end
    end
  end
end
