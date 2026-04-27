# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Orm
      module ActiveRecord
        module Mixins
          module Application
            extend ::ActiveSupport::Concern

            included do
              # Overrides the setter to normalize the value stored in the database
              def post_logout_redirect_uris=(uris)
                if uris.is_a?(Array)
                  super(uris.join("\n"))
                else
                  super
                end
              end

              # Returns the list of registered post-logout redirect URIs as an array.
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
