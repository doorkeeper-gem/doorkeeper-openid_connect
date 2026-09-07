# frozen_string_literal: true

source "https://rubygems.org"

# use Rails version specified by environment
ENV["rails"] ||= "8.0.0"
gem "rails", "~> #{ENV["rails"]}"
gem "rails-controller-testing"

group :development, :rubocop do
  gem "rubocop", "~> 1.6"
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :development do
  gem "puma"

  # The browser end-to-end suite in spec/e2e. `require: false` keeps them out
  # of the dummy application's own Bundler.require.
  gem "capybara", require: false
  gem "cuprite", require: false
end

# json 3.0 (2026-09-07) removed the `quirks_mode` option from `JSON.generate`.
# ActiveSupport's `JSONGemEncoder` still passes it up to and including the 8.0
# series, and `ENV["rails"]` above defaults to 8.0, so an unpinned resolution
# turns every `render json:` in `rake spec` into an `ArgumentError`. Only this
# Gemfile is affected: ActiveSupport 8.0 and 7.x do not depend on the json gem,
# so RuboCop's `json (>= 2.3)` is what pulls it in here, and the CI gemfiles
# that do resolve json 3 run Rails 8.1, which no longer passes the option.
#
# `~> 2.21` rather than `< 3` so 3.0.0.rc1 is not resolvable either, matching
# the pin in gemfiles/rails_8.0.gemfile.
#
# TODO: drop this pin once a released 8.0.x carries the ActiveSupport fix
# (already on 8-0-stable).
gem "json", "~> 2.21"

gemspec
