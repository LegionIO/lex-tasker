# frozen_string_literal: true

require 'bundler/setup'
ENV['LEGION_MODE'] = 'lite'
require 'legion/logging'
Legion::Logging.setup(level: 'fatal', log_file: File::NULL, log_stdout: false, async: false)
require 'legion/settings'
Legion::Settings.loader = Legion::Settings::Loader.new
require 'legion/data'
require 'legion/transport'
require 'legion/transport/connection'
Legion::Transport::Connection.setup
require 'legion/extensions/tasker'
require 'sequel'
require 'timeout'
Sequel.extension :migration

TASKER_SPEC_DB = Sequel.sqlite
Legion::Data::Connection.sequel = TASKER_SPEC_DB
Sequel::Model.db = TASKER_SPEC_DB
migration_root = File.join(Gem.loaded_specs.fetch('legion-data').full_gem_path, 'lib/legion/data/migrations')
Sequel::Migrator.run(TASKER_SPEC_DB, migration_root)
%w[extension runner function relationship task task_log node].each { |model| require "legion/data/models/#{model}" }

module Legion
  module Extensions
    module Actors
      class Every
        include Legion::Settings::Helper
      end

      class Subscription
        include Legion::Settings::Helper
      end
    end
  end
end

module TaskerDatabaseExamples
  def seed_relationship(**attributes)
    extension = Legion::Data::Model::Extension.create(name: 'example', namespace: 'Example', exchange: 'example')
    source = Legion::Data::Model::Runner.create(extension_id: extension.id, name: 'source', queue: 'source', namespace: 'Example::Source')
    target = Legion::Data::Model::Runner.create(extension_id: extension.id, name: 'target', queue: 'target', namespace: 'Example::Target')
    trigger = Legion::Data::Model::Function.create(runner_id: source.id, name: 'produce')
    action = Legion::Data::Model::Function.create(runner_id: target.id, name: 'consume')
    relationship = Legion::Data::Model::Relationship.create({ trigger_id: trigger.id, action_id: action.id, allow_new_chains: true }.merge(attributes))
    parent = Legion::Data::Model::Task.create(function_id: trigger.id, status: 'task.completed').values
    { relationship: relationship, parent: parent, trigger: trigger, action: action }
  end

  def completion_options(fixture:, **overrides)
    { runner_class: 'Example::Source', function: 'produce', task_id: fixture[:parent][:id],
      args: { original: 'input' }, results: { value: 42 }, principal_id: 'principal', principal_type: 'service',
      tenant_id: 'tenant', correlation_id: 'correlation', chain_id: 9, schema: { value: 'integer' },
      engine_options: { strict: true } }.merge(overrides)
  end

  def bind_task_receiver(exchange:, tenant_id: 'tenant')
    declaration = Legion::Transport::Exchange.declaration(name: exchange, tenant_id: tenant_id)
    channel = Legion::Transport::Connection.channel
    queue = channel.queue_declare_without_recording_topology("tasker-spec-#{SecureRandom.uuid}")
    queue.bind(declaration[:name], routing_key: '#')
    (@tasker_queues ||= []) << queue
    received = Queue.new
    queue.subscribe(manual_ack: false) { |_delivery, _properties, body| received << Legion::JSON.load(body) }
    received
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.include TaskerDatabaseExamples
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.before(:suite) do
    # Standalone specs supply the settings mixin that LegionIO injects when building runners.
    Legion::Extensions::Tasker::Runners.constants(false).each do |name|
      Legion::Extensions::Tasker::Runners.const_get(name, false).include(Legion::Settings::Helper)
    end
  end
  config.before do
    Legion::Settings[:extensions][:tasker] = Legion::Extensions::Tasker.default_settings
  end
  config.around do |example|
    Legion::Settings.with_overlay(data: { connected: true }, transport: { messages: { encrypt: false } }) do
      TASKER_SPEC_DB.transaction(rollback: :always, auto_savepoint: true) { example.run }
    end
  end
  config.after { @tasker_queues&.each(&:delete) }
  config.after(:suite) { Legion::Transport::Connection.shutdown }
end
