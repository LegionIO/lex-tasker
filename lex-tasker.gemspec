# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'legion/extensions/tasker/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-tasker'
  spec.version       = Legion::Extensions::Tasker::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX::Tasker manages tasks status from Legion'
  spec.description   = 'This LEX keeps track of tasks and their status'
  spec.homepage      = 'https://github.com/LegionIO/lex-tasker'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-tasker'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-tasker'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-tasker'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-tasker/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 2'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rubocop'
end
