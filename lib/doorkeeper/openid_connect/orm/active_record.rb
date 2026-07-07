# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    autoload :AccessGrant, "doorkeeper/openid_connect/orm/active_record/access_grant"
    autoload :Request, "doorkeeper/openid_connect/orm/active_record/request"

    module Orm
      module ActiveRecord
        module Mixins
          autoload :OpenidRequest,
                   "doorkeeper/openid_connect/orm/active_record/mixins/openid_request"
        end

        # Prepended onto the singleton class of Doorkeeper's AccessGrant
        # mixin so that every model which includes
        # `Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant` — the default
        # `Doorkeeper::AccessGrant` as well as any (possibly namespaced)
        # custom access grant model — also gains the OpenID Connect
        # `openid_request` association.
        #
        # The association is wired from the mixin's `included` callback, at
        # the moment the host model is loaded: `base` is the model class
        # itself, handed to us by Ruby. Nothing reaches out to constantize
        # the configured grant class, so the re-entrant
        # `ActiveSupport.on_load(:active_record)` window that broke
        # namespaced custom models is gone.
        #
        # Background: doorkeeper-openid_connect v1.10.0 (#241) wrapped the
        # grant-model prepend in `ActiveSupport.on_load(:active_record)`,
        # following doorkeeper #1804. doorkeeper later reverted that in
        # #1830 (v5.9.2) because the hook fires while `ActiveRecord::Base`
        # is first loaded — e.g. mid-evaluation of
        # `class ApplicationRecord < ActiveRecord::Base` — at which point
        # constantizing `Auth::OAuthAccessGrant < ApplicationRecord` raises
        # `NameError: uninitialized constant Auth::ApplicationRecord` (#306).
        # We follow the same fix: wire from the mixin instead of on_load.
        module AccessGrantExtension
          def included(base)
            super
            # `base` is a Module (not the model) when the mixin is included
            # into an intermediate ActiveSupport::Concern; the concern defers
            # the include, so this hook fires again with the model class.
            base.prepend(OpenidConnect::AccessGrant) if base.is_a?(Class)
          end
        end
      end
    end
  end

  # Doorkeeper 5.5.x ships the very same mixin file, but only 5.6.0+
  # registers an autoload for `Doorkeeper::Orm::ActiveRecord::Mixins`, so
  # on 5.5.x the constant has to be resolved by requiring it explicitly.
  unless defined?(Orm::ActiveRecord::Mixins::AccessGrant)
    require "doorkeeper/orm/active_record/mixins/access_grant"
  end

  Orm::ActiveRecord::Mixins::AccessGrant.singleton_class.prepend(
    OpenidConnect::Orm::ActiveRecord::AccessGrantExtension,
  )
end
