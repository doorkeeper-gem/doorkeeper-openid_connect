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

gemspec
