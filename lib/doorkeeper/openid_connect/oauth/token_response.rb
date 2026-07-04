# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module OAuth
      module TokenResponse
        attr_accessor :id_token

        def body
          return super unless token.includes_scope?("openid")

          # `id_token` is preset by the flows that carry a nonce (the
          # authorization code and password grants). Grants without one —
          # e.g. refresh_token — reach here with it unset, so build a
          # nonce-less ID Token on the fly.
          #
          # A grant with no resource owner — e.g. client_credentials that
          # happens to carry the openid scope — has no end user, so no ID Token
          # is issued. An ID Token's `sub` identifies the end user; building one
          # here would dereference a nil owner in `sub` / the claim generators
          # and raise (500). The request-built flows (auth code / password /
          # implicit) always set `id_token` and always have an owner.
          id_token = self.id_token
          id_token ||= build_id_token_for(token)
          return super if id_token.nil?

          super
            .merge(id_token: id_token.as_jws_token)
            .reject { |_, value| value.blank? }
        end

        private

        def build_id_token_for(token)
          return if token.resource_owner_id.blank?

          Doorkeeper::OpenidConnect.configuration.id_token_model.new(token)
        end
      end
    end
  end

  OAuth::TokenResponse.prepend OpenidConnect::OAuth::TokenResponse
end
