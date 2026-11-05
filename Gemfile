# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

companion_root = File.expand_path('.ci-dependencies', __dir__)
companion_root = File.expand_path('../..', __dir__) unless Dir.exist?(companion_root)
%w[legion-settings legion-data legion-transport].each do |name|
  path = File.join(companion_root, name)
  gem name, path: path if File.file?(File.join(path, "#{name}.gemspec"))
end

gem 'bundler', '>= 2'
gem 'codecov'
gem 'rake'
gem 'rspec'
gem 'rspec_junit_formatter'
gem 'rubocop'
gem 'rubocop-legion', '~> 0.1'
gem 'sqlite3'
