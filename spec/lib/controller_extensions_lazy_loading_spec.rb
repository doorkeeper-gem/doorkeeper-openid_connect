# frozen_string_literal: true

require "rails_helper"
require "json"
require "open3"

# The engine prepends `AuthorizationsExtension` and `MetadataExtension` from an
# autoloader `on_load` callback instead of naming the controllers in
# `to_prepare` (#407). Naming them there autoloaded both controllers on every
# boot, and with them `Doorkeeper::ApplicationController`, its
# `ActionController::Base` superclass and every helper in the host application.
#
# The difference only shows across a whole boot: once this process has loaded
# the controllers, nothing in it can tell whether they were loaded lazily or
# eagerly. Each example therefore boots the dummy application in a child
# process, in the development environment so that reloading is enabled, and
# reads back what that process observed.
RSpec.describe "Controller extensions prepended when the controllers autoload" do
  def boot_and_inspect(controller, extension)
    env = { "RAILS_ENV" => "development", "DATABASE_URL" => "sqlite3::memory:" }
    script = <<~RUBY
      require "json"
      require "./spec/dummy/config/environment"

      controller = #{controller.inspect}
      extension = #{extension.inspect}
      short_name = controller.delete_prefix("Doorkeeper::").to_sym

      inspect_ancestors = lambda do
        ancestors = controller.constantize.ancestors.map(&:to_s)
        {
          "occurrences" => ancestors.count(extension),
          "prepended" => ancestors.index(extension)&.<(ancestors.index(controller)),
        }
      end

      report = {}
      report["pending_after_boot"] = !Doorkeeper.autoload?(short_name).nil?
      report["after_load"] = inspect_ancestors.call
      Rails.application.reloader.reload!
      report["pending_after_reload"] = !Doorkeeper.autoload?(short_name).nil?
      report["after_reload"] = inspect_ancestors.call

      puts JSON.generate(report)
    RUBY

    stdout, stderr, status = Open3.capture3(
      env, RbConfig.ruby, "-", stdin_data: script, chdir: File.expand_path("../..", __dir__),
    )
    expect(status).to be_success, "booting the dummy application failed:\n#{stderr}"

    JSON.parse(stdout.lines.last)
  end

  shared_examples "an extension prepended on autoload" do |controller, extension|
    it "leaves #{controller} unloaded after boot and prepends #{extension} once it loads" do
      report = boot_and_inspect(controller, extension)

      expect(report["pending_after_boot"]).to be(true), "#{controller} was loaded during boot"
      expect(report["after_load"]).to eq("occurrences" => 1, "prepended" => true)
    end

    it "prepends #{extension} once more onto the reloaded #{controller}" do
      report = boot_and_inspect(controller, extension)

      expect(report["pending_after_reload"]).to be(true), "#{controller} was loaded during reload"
      expect(report["after_reload"]).to eq("occurrences" => 1, "prepended" => true)
    end
  end

  include_examples "an extension prepended on autoload",
                   "Doorkeeper::AuthorizationsController",
                   "Doorkeeper::OpenidConnect::AuthorizationsExtension"

  context "when Doorkeeper serves its own metadata document",
          if: Doorkeeper::OpenidConnect.doorkeeper_metadata_endpoint? do
    include_examples "an extension prepended on autoload",
                     "Doorkeeper::MetadataController",
                     "Doorkeeper::OpenidConnect::MetadataExtension"
  end
end
