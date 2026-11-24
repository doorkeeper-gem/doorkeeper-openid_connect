# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Answers whether a `prompt=none` request can go through without the
        # consent form, and widens what counts as a matching token for such a
        # request (issue #63).
        #
        # Whether an earlier token may stand in for the resource owner's
        # consent is Doorkeeper's decision, and nothing here makes it on
        # Doorkeeper's behalf. Doorkeeper refuses it for public clients
        # (CVE-2023-34246: the client's identity cannot be proven, and
        # another application may be receiving its redirect URI, RFC 8252
        # §8.6), and keeps adding conditions of the same kind — custom
        # access token attributes, clients known only from a metadata
        # document. This module asks Doorkeeper instead of repeating them:
        # a copy that falls behind is a consent bypass.
        module TokenMatching
          private

          # Whether Doorkeeper is going to show the consent form — it calls
          # the same two predicates from
          # AuthorizationsController#render_success. `prompt=none` forbids any
          # interactive UI (OIDC Core §3.1.2.1), so the request has to fail
          # with `consent_required` instead.
          #
          # The argument is not consulted any more: the predicates work on
          # Doorkeeper's `current_resource_owner`. It stays so that existing
          # callers keep working.
          def oidc_consent_required?(_owner = nil)
            !skip_authorization? && !oidc_earlier_token_stands_in_for_consent?
          end

          def oidc_earlier_token_stands_in_for_consent?
            return can_authorize_response? if respond_to?(:can_authorize_response?, true)

            # Doorkeeper < 5.7 has no #can_authorize_response?: the rule sits
            # inline in #render_success, and before 5.6.6 it did not look at
            # the client type at all (CVE-2023-34246). `prompt=none` is held
            # to the fixed rule on every supported version.
            pre_auth.client.application.confidential? && matching_token?
          end

          # Whether a `prompt=none` request finds an earlier token covering
          # more than the scopes it asks for. See
          # AuthorizationsExtension#matching_token?, the only caller.
          def oidc_prompt_none_matching_token?
            @_oidc_prompt_none && oidc_matching_subset_token?(current_resource_owner)
          end

          # Returns true if the resource owner already has an active token for this
          # client whose scopes are a (non-strict) superset of the requested scopes.
          # Used to allow `prompt=none` to succeed when the client re-authorizes
          # with a narrower set of scopes (issue #63).
          #
          # Scans tokens via `find_access_token_in_batches` (same pattern as
          # upstream Doorkeeper's `find_matching_token`) so that installations
          # with many active tokens per (client, resource owner) pair do not
          # load the entire relation into memory.
          def oidc_matching_subset_token?(owner)
            return @oidc_matching_subset_token if defined?(@oidc_matching_subset_token)

            @oidc_matching_subset_token =
              !pre_auth.scopes.empty? && oidc_subset_token_exists?(owner)
          end

          def oidc_subset_token_exists?(owner)
            token_model = Doorkeeper.config.access_token_model
            relation = token_model.authorized_tokens_for(pre_auth.client.id, owner)
            batch_size = Doorkeeper.configuration.token_lookup_batch_size

            token_model.find_access_token_in_batches(relation, batch_size: batch_size) do |batch|
              return true if batch.any? { |token| oidc_token_covers_request?(token) }
            end
            false
          end

          def oidc_token_covers_request?(token)
            token.scopes.scopes?(pre_auth.scopes) && oidc_token_audience_matches?(token)
          end

          # RFC 8707 (Doorkeeper >= 6.0): a token issued for another audience
          # does not match, whatever its scopes. This is the one condition
          # Doorkeeper applies per token, inside its own #matching_token?, so
          # the scan above has to apply it as well.
          def oidc_token_audience_matches?(token)
            token_model = Doorkeeper.config.access_token_model
            return true unless token_model.respond_to?(:resource_indicators_match?)

            token_model.resource_indicators_match?(
              token, pre_auth.resource_indicators&.join(" ").presence,
            )
          end
        end
      end
    end
  end
end
