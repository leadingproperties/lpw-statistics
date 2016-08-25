# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lpw/statistics/version'

Gem::Specification.new do |spec|
  spec.name          = "lpw-statistics"
  spec.version       = Lpw::Statistics::VERSION
  spec.authors       = ["Alex Baidan"]
  spec.email         = ["howtwizer@gmail.com"]

  spec.summary       = %q{Provide class for statistic purposes}
  spec.description   = %q{Write/read custom statistics from Elasticsearch}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency('elasticsearch')
  spec.add_dependency('elasticsearch-persistence')
  spec.add_dependency('pathname')
  spec.add_dependency('fileutils')
  spec.add_dependency('multi_json')

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
end
