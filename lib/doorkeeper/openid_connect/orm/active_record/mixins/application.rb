# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Orm
      module ActiveRecord
        module Mixins
          module Application
            extend ::ActiveSupport::Concern

            MISSING_COLUMN_MESSAGE =
              "can't write post_logout_redirect_uris: the oauth_applications column is missing — " \
              "run `rails generate doorkeeper:openid_connect:add_post_logout_redirect_uris` " \
              "and `rails db:migrate`"

            # The client's Back-Channel Logout URI (Back-Channel Logout 1.0
            # §2.2), validated with the same `Doorkeeper::RedirectUriValidator`
            # rules as `redirect_uri` — which enforces exactly what §2.2
            # requires (absolute URI, no fragment, forbidden schemes) and
            # keeps the https requirement in lockstep with
            # `force_ssl_in_redirect_uri`. Registration is optional, so a
            # blank value is allowed (the client then receives no Logout
            # Tokens).
            #
            # As with the `post_logout_redirect_uris` handling below, all
            # paths degrade gracefully when the column has not been added yet
            # (an existing installation that has not run the upgrade
            # migration): reads answer nil, validation is skipped — only an
            # explicit write raises, pointing at the missing migration,
            # because silently dropping an assigned logout URI would surface
            # much later as an RP that never receives logout notifications.
            module BackchannelLogout
              extend ::ActiveSupport::Concern

              BACKCHANNEL_LOGOUT_URI_MISSING_COLUMN_MESSAGE =
                "can't write backchannel_logout_uri: the oauth_applications column is missing — " \
                "run `rails generate doorkeeper:openid_connect:add_backchannel_logout_uri` " \
                "and `rails db:migrate`"

              included do
                validate do
                  next unless has_attribute?(:backchannel_logout_uri)

                  raw_value = read_attribute(:backchannel_logout_uri)
                  next if raw_value.blank?

                  Doorkeeper::RedirectUriValidator
                    .new(attributes: [:backchannel_logout_uri])
                    .validate_each(self, :backchannel_logout_uri, raw_value)
                end

                def backchannel_logout_uri=(uri)
                  unless has_attribute?(:backchannel_logout_uri)
                    raise ActiveModel::MissingAttributeError,
                          BACKCHANNEL_LOGOUT_URI_MISSING_COLUMN_MESSAGE
                  end

                  super
                end

                # Returns nil for both the missing-column case and a stored
                # blank value, so callers can treat "no logout URI registered"
                # as one condition.
                def backchannel_logout_uri
                  return nil unless has_attribute?(:backchannel_logout_uri)

                  super.presence
                end
              end
            end

            include BackchannelLogout

            included do
              # Validate registered post-logout redirect URIs with exactly the
              # same rules Doorkeeper applies to `redirect_uri`, by delegating
              # to its own `Doorkeeper::RedirectUriValidator`. This keeps the
              # two attributes in lockstep (forbidden schemes such as
              # `javascript:`, fragments, relative/opaque URIs, missing host
              # and `force_ssl_in_redirect_uri`) without re-implementing any of
              # that logic here.
              #
              # Per the RP-Initiated Logout spec the registration is optional,
              # so a blank value is allowed (no `post_logout_redirect_uri` may
              # then be used at logout time).
              #
              # Skipped entirely when the column has not been added yet (an
              # existing installation that has not run the upgrade migration),
              # so saving applications keeps working without it.
              validate do
                next unless has_attribute?(:post_logout_redirect_uris)

                raw_value = read_attribute(:post_logout_redirect_uris)
                next if raw_value.blank?

                Doorkeeper::RedirectUriValidator
                  .new(attributes: [:post_logout_redirect_uris])
                  .validate_each(self, :post_logout_redirect_uris, raw_value)
              end

              # Normalizes the value stored in the database. An array is stored
              # as a newline-separated string, mirroring how Doorkeeper handles
              # `redirect_uri` (see Doorkeeper's ApplicationMixin#redirect_uri=).
              #
              # Unlike the read paths (getter, validation, DCR), writing without
              # the column is not silently ignored: dropping a value the caller
              # explicitly assigned would surface much later as a mysteriously
              # rejected logout redirect. Raise a clear error pointing at the
              # missing migration instead of the bare `super: no superclass
              # method` NoMethodError.
              def post_logout_redirect_uris=(uris)
                unless has_attribute?(:post_logout_redirect_uris)
                  raise ActiveModel::MissingAttributeError, MISSING_COLUMN_MESSAGE
                end

                super(uris.is_a?(Array) ? uris.join("\n") : uris)
              end

              # Returns the list of registered post-logout redirect URIs as an
              # array. The stored value is whitespace/newline-separated, matching
              # the way Doorkeeper parses `redirect_uri`.
              #
              # Returns an empty array when the `post_logout_redirect_uris`
              # column has not been added yet (an existing installation that has
              # not run the upgrade migration), so logout-time validation and
              # the DCR response degrade gracefully instead of raising.
              def post_logout_redirect_uris
                return [] unless has_attribute?(:post_logout_redirect_uris)

                super.to_s.split
              end

              # Checks whether the given URI is a valid post-logout redirect URI
              # for this application, i.e. it has been previously registered.
              #
              # @param uri [String] the post-logout redirect URI to validate
              #
              # @return [Boolean] true if the URI is registered, false otherwise
              #
              def valid_post_logout_redirect_uri?(uri)
                return false if uri.blank?

                post_logout_redirect_uris.include?(uri.to_s)
              end
            end
          end
        end
      end
    end
  end
end
