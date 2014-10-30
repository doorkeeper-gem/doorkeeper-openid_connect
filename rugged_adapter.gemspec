# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rugged_adapter/version"

Gem::Specification.new do |s|
  s.name        = "gollum-rugged_adapter"
  s.version     = Gollum::Lib::Git::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bart Kamphorst, Dawa Ometto"]
  s.email       = ["repotag-dev@googlegroups.com"]
  s.homepage    = "https://github.com/gollum/rugged_adapter"
  s.summary     = %q{Adapter for Gollum to use Rugged (libgit2) at the backend.}
  s.description = %q{Adapter for Gollum to use Rugged (libgit2) at the backend.}
  s.license	= "MIT"

  s.add_runtime_dependency 'rugged', '~> 0.21'
  s.add_development_dependency "rspec", "2.13.0"

  s.files         = Dir['lib/**/*.rb'] + ["README.md", "Gemfile"]
  s.require_paths = ["lib"]
end

