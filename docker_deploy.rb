#!/usr/bin/env ruby

name = 'tasker'
require "./lib/legion/extensions/#{name}/version"
version = Legion::Extensions::Tasker::VERSION

puts "Building docker image for Legion v#{version}"
system("docker build --tag legionio/lex-#{name}:v#{version} .")
puts 'Pushing to hub.docker.com'
system("docker push legionio/lex-#{name}:v#{version}")
system("docker tag legionio/lex-#{name}:v#{version} legionio/lex-#{name}:latest")
system("docker push legionio/lex-#{name}:latest")
puts 'completed'
