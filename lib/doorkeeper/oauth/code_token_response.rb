module Doorkeeper
  module OAuth
    class CodeTokenResponse < CodeIdTokenTokenResponse
      def redirect_uri
        Authorization::URIBuilder.uri_with_fragment(
          pre_auth.redirect_uri,
          code: auth.token.token,
          access_token: auth_token.token.token,
          token_type: auth_token.token.token_type,
          expires_in: auth_token.token.expires_in_seconds,
          state: pre_auth.state
        )
      end

      def form_response
        response_form(pre_auth.redirect_uri,
                      auth.token.token,
                      auth_token.token.token,
                      auth_token.token.token_type,
                      auth_token.token.expires_in_seconds,
                      pre_auth.state)
      end

      def response_form(redirect_uri, code, access_token, token_type, expires_in, state)
        <<~EOT.html_safe
          <html>
            <head>
              <title>Submit This Form</title>
            </head>
            <body onload="javascript:document.forms[0].submit()">
              <form method="post" action="#{redirect_uri}">
                <input type="hidden" name="state" value="#{state}"/>
                <input type="hidden" name="code" value="#{code}"/>
                <input type="hidden" name="access_token" value="#{access_token}"/>
                <input type="hidden" name="token_type" value="#{token_type}"/>
                <input type="hidden" name="expires_in" value="#{expires_in}"/>
              </form>
            </body>
          </html>
        EOT
      end
    end
  end
end
