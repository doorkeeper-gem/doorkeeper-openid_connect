# coding: utf-8
$:.push File.expand_path("../lib", __FILE__)
require 'doorkeeper/openid_connect/version'

Gem::Specification.new do |spec|
  spec.name          = "doorkeeper-openid_connect"
  spec.version       = Doorkeeper::OpenidConnect::VERSION
  spec.authors       = ["sdengler"]
  spec.email         = ["sam.dengler@playonsports.com"]
  spec.homepage      = "https://github.com/doorkeeper-gem/doorkeeper/doorkeeper-openid_connect"
  spec.summary       = %q{OpenID Connect extension to Doorkeeper.}
  spec.description   = %q{OpenID Connect extension to Doorkeeper.}
  spec.license       = %q{MIT}

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 3.1"
  spec.add_dependency "doorkeeper", ">= 1.3"
  spec.add_development_dependency "rspec-rails", ">= 2.11.4"
  spec.add_development_dependency "capybara", "~> 1.1.2"
  spec.add_development_dependency "factory_girl", "~> 2.6.4"
  spec.add_development_dependency "generator_spec", "~> 0.9.0"
  spec.add_development_dependency "database_cleaner", "~> 1.2.0"
end
