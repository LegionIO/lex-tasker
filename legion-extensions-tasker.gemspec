lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'legion/extensions/tasker/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-tasker'
  spec.version       = Legion::Extensions::Tasker::VERSION
  spec.authors       = ['Miverson']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX::Tasker manages tasks status from Legion'
  spec.description   = 'This LEX keeps track of tasks and their status'
  spec.homepage      = 'https://bitbucket.org/legion-io/lex-tasker'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-performance'
end
