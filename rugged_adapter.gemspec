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

  s.add_runtime_dependency 'rugged', '~> 0.28', '>= 0.28.2'
  s.add_runtime_dependency 'mime-types', '>= 1.15'
  s.add_development_dependency "rspec", "3.4.0"  

  s.files         = Dir['lib/**/*.rb'] + ["README.md", "Gemfile"]
  s.require_paths = ["lib"]

  # = MANIFEST =
  s.files = %w(
    Gemfile
    LICENSE
    README.md
    Rakefile
    lib/rugged_adapter.rb
    lib/rugged_adapter/git_layer_rugged.rb
    lib/rugged_adapter/version.rb
    rugged_adapter.gemspec
  )
  # = MANIFEST =

end
