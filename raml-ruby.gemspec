# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'raml/version'

Gem::Specification.new do |spec|
  spec.name          = "raml-ruby"
  spec.version       = Raml::VERSION
  spec.authors       = ["kgorin", 'insoul']
  spec.email         = ["me@kgor.in", 'ensoul@empal.com']
  spec.description   = %q{Raml Ruby Parser}
  spec.summary       = %q{Raml Ruby Parser}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'uri_template', '~> 0.7'
  
  spec.add_development_dependency 'bundler', "~> 1.3"
  spec.add_development_dependency 'rake'   , '~> 10.0'
  spec.add_development_dependency 'rspec'  , '~> 3.0'
  spec.add_development_dependency 'rr'     , '~> 1.1' 
  spec.add_development_dependency "pry"    , '~> 0.10'
end
