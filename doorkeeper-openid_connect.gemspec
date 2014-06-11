# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'doorkeeper/openid_connect/version'

Gem::Specification.new do |spec|
  spec.name          = "doorkeeper-openid_connect"
  spec.version       = Doorkeeper::OpenIdConnect::VERSION
  spec.authors       = ["Sam Dengler"]
  spec.email         = ["sam.dengler@playonsports.com"]
  spec.summary       = "OpenID Connect Extension to Doorkeeper"
  spec.description   = "OpenID Connect Extension to Doorkeeper"
  spec.homepage      = "https://github.com/doorkeeper-gem/doorkeeper/doorkeeper-openid_connect"
  spec.license       = "MIT"

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
