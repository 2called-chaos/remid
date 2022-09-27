# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'remid/version'

Gem::Specification.new do |spec|
  spec.name          = "remid"
  spec.version       = Remid::VERSION
  spec.authors       = ["Sven Pachnit"]
  spec.email         = ["sven@bmonkeys.net"]
  spec.summary       = %q{REMID: Ruby Enhanced MInecraft Datapacks}
  spec.description   = %q{Datapacks but with a bit less old pain and a bit new fresh pain}
  spec.homepage      = "https://github.com/2called-chaos/remid"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 6.1"
  spec.add_dependency "rainbow"#, ">= 6.1"
  spec.add_dependency "listen"#, ">= 6.1"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
end
