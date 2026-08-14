# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  # The end-to-end suite boots the dummy application in the development
  # environment, so it cannot share this process. `rake e2e` runs it.
  t.rspec_opts = %(--exclude-pattern "spec/e2e/**/*_spec.rb")
end

task default: :spec
task test: :spec

desc "Generate and run migrations in the test application"
task :migrate do
  ENV["RAILS_ENV"] ||= "test"
  Dir.chdir("spec/dummy") do
    system("bin/rails generate doorkeeper:openid_connect:migration")
    system("bin/rake db:migrate")
  end
end

desc "Run server in the test application"
task :server do
  ENV["RAILS_ENV"] ||= "development"
  Dir.chdir("spec/dummy") do
    system("bin/rails server")
  end
end

desc "Run browser end-to-end tests against the test application"
RSpec::Core::RakeTask.new(:e2e) do |t|
  t.pattern = "spec/e2e/**/*_spec.rb"
end
