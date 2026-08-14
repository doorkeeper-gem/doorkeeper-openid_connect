# frozen_string_literal: true

# The end-to-end suite drives a real browser against the dummy application, so
# it boots that application the way `rake server` does — in the development
# environment — instead of the test environment the rest of the suite uses.
# Development is what makes the dashboard usable end to end: Doorkeeper skips
# the consent screen there unless `force_consent` asks for it, and it accepts
# the plain-http redirect URIs the dashboard hands out.
#
# One process can only boot the application once, so these specs are excluded
# from `rake spec` and run on their own through `rake e2e`.
if defined?(Rails.env) && !Rails.env.development?
  raise <<~MESSAGE
    The end-to-end suite boots the dummy application in the development
    environment, so it cannot share a process with the specs that boot it in
    the #{Rails.env} environment. Run it on its own:

        bundle exec rake e2e
  MESSAGE
end

ENV["RAILS_ENV"] = "development"
# Its own database, so a run never disturbs the one behind `rake server`.
# Relative paths resolve against Rails.root, i.e. spec/dummy/db/e2e.sqlite3.
ENV["DATABASE_URL"] = "sqlite3:db/e2e.sqlite3"

require "capybara/rspec"
require "capybara/cuprite"
require "dummy/config/environment"
require "spec_helper"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

# Every run starts from an empty database: the specs create the users and
# applications they need through the dashboard, and nothing should survive a
# run to make the next one pass.
ActiveRecord::Schema.verbose = false
load Rails.root.join("db/schema.rb")

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1400, 1000],
    # HEADLESS=false opens a visible browser, which is the quickest way to see
    # what a failing flow actually does.
    headless: ENV["HEADLESS"] != "false",
    timeout: 20,
    process_timeout: 30,
    browser_options: {
      # This browser only ever loads the dummy application from 127.0.0.1, and
      # its sandbox needs the unprivileged user namespaces that the Ubuntu CI
      # runners disable.
      "no-sandbox" => nil,
      "disable-dev-shm-usage" => nil,
    },
  )
end

Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 10
Capybara.disable_animation = true
Capybara.save_path = Rails.root.join("tmp/e2e")

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/e2e/}) do |metadata|
    metadata[:type] = :feature
  end

  config.include Dashboard, type: :feature

  # Capybara resets the session in an `after` hook of its own. This one is
  # declared later, so RSpec runs it first and it still has the failed page to
  # photograph.
  config.after(type: :feature) do |example|
    next unless example.exception

    name = example.full_description.gsub(/[^\w]+/, "-").delete_suffix("-")[0, 120]
    page.save_screenshot("#{name}.png")
    page.save_page("#{name}.html")
    warn "Saved the failed page to #{Capybara.save_path}/#{name}.{png,html}"
  rescue StandardError => e
    warn "Could not save the failed page: #{e.class}: #{e.message}"
  end
end
