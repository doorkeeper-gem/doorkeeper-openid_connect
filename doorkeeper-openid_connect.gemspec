$:.push File.expand_path('../lib', __FILE__)
require 'doorkeeper/openid_connect/version'

Gem::Specification.new do |spec|
  spec.name          = 'doorkeeper-openid_connect'
  spec.version       = Doorkeeper::OpenidConnect::VERSION
  spec.authors       = ['Sam Dengler', 'Markus Koller']
  spec.email         = ['sam.dengler@playonsports.com', 'markus-koller@gmx.ch']
  spec.homepage      = 'https://github.com/doorkeeper-gem/doorkeeper-openid_connect'
  spec.summary       = %q{OpenID Connect extension for Doorkeeper.}
  spec.description   = %q{OpenID Connect extension for Doorkeeper.}
  spec.license       = %q{MIT}

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = ">= 2.4"

  spec.add_runtime_dependency 'doorkeeper', '>= 5.2', '< 5.5'
  spec.add_runtime_dependency 'json-jwt', '>= 1.11.0'

  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'factory_bot'
  # We need to stick to this sqlite3 version for Rails 5.0
  # https://github.com/rails/rails/pull/35154
  spec.add_development_dependency 'sqlite3', '~> 1.3.6'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'conventional-changelog', '~> 1.2'
end
