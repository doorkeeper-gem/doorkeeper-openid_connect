# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    autoload :AccessGrant, "doorkeeper/openid_connect/orm/active_record/access_grant"
    autoload :Request, "doorkeeper/openid_connect/orm/active_record/request"

    module Orm
      module ActiveRecord
        module Mixins
          autoload :Application,
                   "doorkeeper/openid_connect/orm/active_record/mixins/application"
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

        # Prepended onto the singleton class of Doorkeeper's Application
        # mixin so that every model which includes
        # `Doorkeeper::Orm::ActiveRecord::Mixins::Application` — the default
        # `Doorkeeper::Application` as well as any (possibly namespaced)
        # custom application model — also gains the OpenID Connect
        # `post_logout_redirect_uris` accessors used for RP-Initiated Logout
        # validation.
        #
        # This mirrors AccessGrantExtension: the OIDC mixin is wired from the
        # host mixin's `included` callback, so nothing reaches out to
        # constantize the configured application class and the re-entrant
        # `ActiveSupport.on_load(:active_record)` window that broke namespaced
        # custom models (#306) is avoided.
        module ApplicationExtension
          def included(base)
            super
            # `base` is a Module (not the model) when the mixin is included
            # into an intermediate ActiveSupport::Concern; the concern defers
            # the include, so this hook fires again with the model class.
            base.include(Mixins::Application) if base.is_a?(Class)
          end
        end
      end
    end
  end

  Orm::ActiveRecord::Mixins::AccessGrant.singleton_class.prepend(
    OpenidConnect::Orm::ActiveRecord::AccessGrantExtension,
  )

  Orm::ActiveRecord::Mixins::Application.singleton_class.prepend(
    OpenidConnect::Orm::ActiveRecord::ApplicationExtension,
  )
end
