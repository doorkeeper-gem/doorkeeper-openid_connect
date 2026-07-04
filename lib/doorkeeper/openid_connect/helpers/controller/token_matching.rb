# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Decides whether an already-issued access token can satisfy the
        # current authorization request, so `prompt=none` can succeed (or
        # consent can be skipped) without interactive UI.
        module TokenMatching
          private

          def oidc_consent_required?(owner)
            !skip_authorization? && !matching_token? && !oidc_matching_subset_token?(owner)
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

            match_found = false
            token_model.find_access_token_in_batches(relation, batch_size: batch_size) do |batch|
              if batch.any? { |token| token.scopes.scopes?(pre_auth.scopes) }
                match_found = true
                break
              end
            end
            match_found
          end

          # Force Doorkeeper's `render_success` onto the auto-issue path when a
          # `prompt=none` subset-scope reauthorization has been validated above.
          def skip_authorization?
            return true if @_oidc_prompt_none_skip_authorization

            super
          end
        end
      end
    end
  end
end
