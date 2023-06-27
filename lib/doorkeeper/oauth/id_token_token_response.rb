# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class IdTokenTokenResponse < IdTokenResponse
      def body
        super.merge({
          access_token: auth.token.token,
          token_type: auth.token.token_type
        })
      end

      def form_response
        response_form(pre_auth.redirect_uri,
                      auth.token.token,
                      auth.token.token_type,
                      auth.token.expires_in_seconds,
                      pre_auth.state,
                      id_token.as_jws_token)
      end

      def response_form(redirect_uri, access_token, token_type, expires_in, state, id_token)
        <<~EOT.html_safe
          <html>
            <head>
              <title>Submit This Form</title>
            </head>
            <body onload="javascript:document.forms[0].submit()">
              <form method="post" action="#{redirect_uri}">
                <input type="hidden" name="state" value="#{state}"/>
                <input type="hidden" name="access_token" value="#{access_token}"/>
                <input type="hidden" name="token_type" value="#{token_type}"/>
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
