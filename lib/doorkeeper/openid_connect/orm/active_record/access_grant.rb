# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module AccessGrant
      class << self
        # Wiring the `openid_request` association needs
        # `open_id_request_class`, so it can only run once
        # `Doorkeeper::OpenidConnect.configure` has. The grant model is not
        # guaranteed to load after that: Doorkeeper's own `initialize_models!`
        # reaches for it from `Doorkeeper.configure` (immediately, when a
        # railtie has already loaded `ActiveRecord::Base`), and any initializer
        # sorting between `doorkeeper.rb` and `doorkeeper_openid_connect.rb`
        # can name the model itself. Reading the configuration here would raise
        # `MissingConfiguration` in both cases — with a message pointing at an
        # initializer that does exist and simply has not run yet.
        #
        # So wire immediately when the configuration is there, and otherwise
        # remember the host model and wire it from `configure`.
        def prepended(base)
          return pending_hosts << base unless OpenidConnect.configured?

          wire_openid_request_association(base)
        end

        # Called from `Doorkeeper::OpenidConnect.configure` for the models that
        # loaded before it.
        def wire_pending_hosts
          pending_hosts.each { |base| wire_openid_request_association(base) }
          pending_hosts.clear
        end

        private

        def pending_hosts
          @pending_hosts ||= []
        end

        def wire_openid_request_association(base)
          base.class_eval do
            has_one :openid_request,
                    class_name: Doorkeeper::OpenidConnect.configuration.open_id_request_class,
                    foreign_key: "access_grant_id",
                    inverse_of: :access_grant,
                    dependent: :delete
          end
        end
      end
    end
  end
end
