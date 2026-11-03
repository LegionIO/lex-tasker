# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/fetch_delayed'
require 'legion/extensions/tasker/data/delayed_dispatch_migration'

RSpec.describe Legion::Extensions::Tasker::Data::DelayedDispatchMigration do
  let(:migration_path) { File.expand_path('../../../../../lib/legion/extensions/tasker/data/migrations', __dir__) }

  def legacy_delayed_task(fixture:, **overrides)
    parent_id = fixture[:parent][:id]
    snapshot = {
      relationship_id: fixture[:relationship].id, function_id: fixture[:action].id, function: 'consume',
      runner_class: 'Example::Target', runner_routing_key: 'example.target.consume',
      delay: 30, conditions: '{"all":[]}', transformation: '{}', engine: 'erb',
      parent_id: parent_id, master_id: parent_id, routing_key: 'task.subtask.conditioner',
      results: { value: 42 }, payload: completion_options(fixture: fixture, deadline_at: Time.now + 600)
    }.merge(overrides)
    id = TASKER_SPEC_DB[:tasks].insert(relationship_id: fixture[:relationship].id, function_id: fixture[:action].id,
                                       parent_id: parent_id, master_id: parent_id, status: 'task.delayed', payload: Legion::JSON.dump(snapshot))
    TASKER_SPEC_DB[:tasks].where(id: id).first
  end

  def migrate(target: 2)
    Sequel::Migrator.run(TASKER_SPEC_DB, migration_path, table: :tasker_schema_info, target: target)
  end

  it 'converts the original persisted flat snapshot and dispatches it without reading a changed relationship' do
    fixture = seed_relationship
    task = legacy_delayed_task(fixture: fixture)
    fixture[:relationship].update(delay: 900, conditions: nil, transformation: '{"changed":true}', engine: 'liquid')

    Legion::Settings.with_overlay(task_execution: { statuses: { delayed: 'local.delayed' }, routes: { conditioner: 'local.conditioner' },
                                                  message_types: { subtask: 'local.subtask' }, protocol: { metadata_fields: [:untrusted] } }) do
      migrate
    end
    canonical = TASKER_SPEC_DB[:tasks].where(id: task[:id]).first
    descriptor = Legion::JSON.load(canonical[:payload])
    expect(descriptor).to include(event_key: "task:#{task[:id]}:legacy-dispatch", message_type: 'subtask')
    expect(descriptor[:options]).to include(task_id: task[:id], conditions: '{"all":[]}', transformation: '{}', engine: 'erb',
                                            args: { value: 42 }, function_args: { original: 'input' }, principal_id: 'principal', tenant_id: 'tenant',
                                            routing_key: 'task.subtask.conditioner')
    expect(canonical[:task_delay]).to eq(30)
    expect(canonical[:deadline_at]).not_to be_nil
    expect(Legion::Extensions::Tasker::Runners::FetchDelayed.fetch(now: task[:created] + 30)).to include(dispatched: 1)
    expect(Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])).to eq(descriptor[:options])
    migrate
    expect(TASKER_SPEC_DB[:tasker_delayed_dispatch_backups].count).to eq(1)
  end

  it 'rolls back every conversion when a historical task cannot be recovered and identifies that task' do
    fixture = seed_relationship
    recoverable = legacy_delayed_task(fixture: fixture)
    invalid = legacy_delayed_task(fixture: fixture, runner_class: nil)

    expect { migrate }.to raise_error(Sequel::DatabaseError, /#{invalid[:id]}:/)
    expect(TASKER_SPEC_DB[:tasks].where(id: recoverable[:id]).first[:payload]).to eq(recoverable[:payload])
    expect(TASKER_SPEC_DB[:tasks].where(id: invalid[:id]).first[:payload]).to eq(invalid[:payload])
    expect(TASKER_SPEC_DB[:tasker_delayed_dispatch_backups].count).to eq(0)
    expect(TASKER_SPEC_DB[:tasker_schema_info].get(:version)).to eq(1)
  end

  it 'restores exact legacy task values on rollback before dispatch' do
    fixture = seed_relationship
    original = legacy_delayed_task(fixture: fixture)
    migrate
    Legion::Settings.with_overlay(task_execution: { statuses: { delayed: 'other.delayed' } }) do
      migrate(target: 0)
    end
    expect(TASKER_SPEC_DB[:tasks].where(id: original[:id]).first).to eq(original)
    expect(TASKER_SPEC_DB.table_exists?(:tasker_delayed_dispatch_backups)).to be(false)
  end

  it 'refuses destructive rollback after a converted task has advanced and preserves its recovery evidence' do
    fixture = seed_relationship
    original = legacy_delayed_task(fixture: fixture)
    migrate
    Legion::Extensions::Tasker::Runners::FetchDelayed.fetch(now: original[:created] + 30)

    expect { migrate(target: 0) }.to raise_error(Sequel::DatabaseError, /#{original[:id]}/)
    expect(TASKER_SPEC_DB[:tasks].where(id: original[:id]).get(:status)).to eq('task.dispatching')
    expect(TASKER_SPEC_DB[:tasker_delayed_dispatch_backups].count).to eq(1)
    expect(TASKER_SPEC_DB[:tasker_schema_info].get(:version)).to eq(2)
  end
end
