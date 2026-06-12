# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Orm
      module ActiveRecord
        module Mixins
          module OpenidRequest
            extend ::ActiveSupport::Concern

            included do
              self.table_name = "#{table_name_prefix}oauth_openid_requests#{table_name_suffix}".to_sym

              # Legacy multi-database support: older Doorkeeper releases let
              # users route the ORM models to a separate connection via
              # `active_record_options[:establish_connection]`. Doorkeeper
              # 5.9.x no longer exposes `active_record_options`, so the guard
              # makes this a no-op there. It used to live in the ORM adapter's
              # `run_hooks`; wiring it from the model's own `included` block
              # keeps it off the re-entrant `on_load(:active_record)` path.
              if Doorkeeper.configuration.respond_to?(:active_record_options) &&
                 (connection_options = Doorkeeper.configuration.active_record_options[:establish_connection])
                establish_connection(connection_options)
              end

              validates :access_grant_id, :nonce, presence: true

              if Gem.loaded_specs["doorkeeper"].version >= Gem::Version.create("5.5.0")
                belongs_to :access_grant,
                           class_name: Doorkeeper.config.access_grant_class.to_s,
                           inverse_of: :openid_request
              else
                belongs_to :access_grant,
                           class_name: "Doorkeeper::AccessGrant",
                           inverse_of: :openid_request
              end
            end
          end
        end
      end
    end
  end
end
