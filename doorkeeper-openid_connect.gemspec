# coding: utf-8
$:.push File.expand_path('../lib', __FILE__)
require 'doorkeeper/openid_connect/version'

Gem::Specification.new do |spec|
  spec.name          = 'doorkeeper-openid_connect'
  spec.version       = Doorkeeper::OpenidConnect::VERSION
  spec.authors       = ['Sam Dengler']
  spec.email         = ['sam.dengler@playonsports.com']
  spec.homepage      = 'https://github.com/playon/doorkeeper-openid_connect'
  spec.summary       = %q{OpenID Connect extension to Doorkeeper.}
  spec.description   = %q{OpenID Connect extension to Doorkeeper.}
  spec.license       = %q{MIT}

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'doorkeeper', '~> 4.0'
  spec.add_runtime_dependency 'json-jwt', '~> 1.6.5'

  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'factory_girl'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'pry-byebug'
end
