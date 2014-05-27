# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mspire/envelope_extractor/version'

Gem::Specification.new do |spec|
  spec.name          = "mspire-envelope_extractor"
  spec.version       = Mspire::EnvelopeExtractor::VERSION
  spec.authors       = ["John T. Prince"]
  spec.email         = ["jtprince@gmail.com"]
  spec.summary       = %q{Extracts isotope envelopes given an mzidentml (.mzid) file}
  spec.description   = %q{Extracts isotope envelopes from mzML files given an mzidentml (.mzid) file}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  [
    ["mspire", "~> 0.10.7"],
    ["nokogiri", "~> 1.6.2"],
    ["bsearch", ">= 1.5.0"],
  ].each do |args|
    spec.add_dependency(*args)
  end

  [
    ["bundler", "~> 1.5.1"],
    ["rake"],
    ["rspec", "~> 2.14.1"], 
    ["rdoc", "~> 4.1.0"], 
    ["simplecov", "~> 0.8.2"],
  ].each do |args|
    spec.add_development_dependency(*args)
  end

end
