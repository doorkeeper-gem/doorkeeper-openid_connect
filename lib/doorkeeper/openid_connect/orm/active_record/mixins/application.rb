# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Orm
      module ActiveRecord
        module Mixins
          module Application
            extend ::ActiveSupport::Concern

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
              validate do
                raw_value = read_attribute(:post_logout_redirect_uris)
                next if raw_value.blank?

                Doorkeeper::RedirectUriValidator
                  .new(attributes: [:post_logout_redirect_uris])
                  .validate_each(self, :post_logout_redirect_uris, raw_value)
              end

              # Normalizes the value stored in the database. An array is stored
              # as a newline-separated string, mirroring how Doorkeeper handles
              # `redirect_uri` (see Doorkeeper's ApplicationMixin#redirect_uri=).
              def post_logout_redirect_uris=(uris)
                super(uris.is_a?(Array) ? uris.join("\n") : uris)
              end

              # Returns the list of registered post-logout redirect URIs as an
              # array. The stored value is whitespace/newline-separated, matching
              # the way Doorkeeper parses `redirect_uri`.
              def post_logout_redirect_uris
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
