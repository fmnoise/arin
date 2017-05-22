# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'arin/version'

Gem::Specification.new do |spec|
  spec.name          = "arin"
  spec.version       = Arin::VERSION
  spec.authors       = ["fmnoise@gmail.com"]
  spec.email         = ["fmnoise@gmail.com"]
  spec.summary       = "ActiveRecord Integrity checking tool"
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/fmnoise/arin"

  spec.files = Dir['lib/**/*.rb'] + Dir['bin/*']
  spec.files += Dir['[A-Z]*'] + Dir['spec/**/*']

  spec.require_paths = ["lib"]
  spec.add_dependency "activerecord", "~> 4.0"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
