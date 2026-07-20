# frozen_string_literal: true

require "rails/generators/active_record"

module Doorkeeper
  module OpenidConnect
    # Adds the `post_logout_redirect_uris` column to `oauth_applications` for
    # applications that were installed before the column was introduced. New
    # installations already get the column via the regular install migration
    # (see MigrationGenerator), so this generator is only needed when upgrading
    # an existing installation.
    class AddPostLogoutRedirectUrisGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)
      desc "Adds the post_logout_redirect_uris column to oauth_applications (existing installs)."

      def install
        migration_template(
          "add_post_logout_redirect_uris.rb.erb",
          "db/migrate/add_post_logout_redirect_uris_to_oauth_applications.rb",
          migration_version: migration_version,
        )
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      private

      def migration_version
        return unless ActiveRecord::VERSION::MAJOR >= 5

        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
