require 'simplecov'
SimpleCov.start

require 'rugged_adapter'

gem_spec = Gem::Specification.find_by_name('adapter_specs')
gem_spec_dir = "#{gem_spec.gem_dir}/#{gem_spec.require_paths[0]}"
Dir.glob("#{gem_spec_dir}/**/*.rb").each {|spec| require "#{spec}"}

