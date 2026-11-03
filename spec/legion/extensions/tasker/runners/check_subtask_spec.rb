# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/check_subtask'

RSpec.describe Legion::Extensions::Tasker::Runners::CheckSubtask do
  subject(:runner) { described_class }

  it 'creates one logical child and one outbox intent across redelivery' do
    fixture = seed_relationship
    options = completion_options(fixture: fixture)
    first = runner.check_subtasks(**options)
    replay = runner.check_subtasks(**options)

    expect(first).to include(success: true, subtasks: 1, created: 1)
    expect(replay).to include(created: 0, task_ids: first[:task_ids])
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(1)
    child = Legion::Data::Model::Task[first[:task_ids].first]
    dispatch = Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])
    expect(child.values).to include(parent_id: fixture[:parent][:id], master_id: fixture[:parent][:id], status: 'task.queued', depth: 1)
    expect(dispatch).to include(task_id: child.id, args: { value: 42 }, results: { value: 42 }, function_args: { original: 'input' },
                                principal_id: 'principal', tenant_id: 'tenant', schema: { value: 'integer' }, engine_options: { strict: true })
  end

  it 'routes a short explicit transformation to the transformer stage' do
    fixture = seed_relationship(engine: 'erb', transformation: '{}')
    result = runner.check_subtasks(**completion_options(fixture: fixture))
    child = Legion::Data::Model::Task[result[:task_ids].first]
    dispatch = TASKER_SPEC_DB[:task_dispatches].first
    expect(child[:status]).to eq('transformer.queued')
    expect(dispatch[:message_type]).to eq('transform')
    expect(Legion::JSON.load(dispatch[:options])).to include(transformation: '{}', engine: 'erb', routing_key: 'task.subtask.transform')
  end

  it 'conditions precede transformations while retaining the later stage template' do
    fixture = seed_relationship(conditions: '{"all":[]}', transformation: '{"ok":true}', engine: 'erb')
    result = runner.check_subtasks(**completion_options(fixture: fixture))
    expect(Legion::Data::Model::Task[result[:task_ids].first][:status]).to eq('conditioner.queued')
    options = Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])
    expect(options).to include(conditions: '{"all":[]}', transformation: '{"ok":true}', routing_key: 'task.subtask.conditioner')
  end

  it 'assigns stable distinct child identities to each fanout result' do
    fixture = seed_relationship
    options = completion_options(fixture: fixture, results: [{ value: 1 }, { value: 2 }])
    first = runner.check_subtasks(**options)
    replay = runner.check_subtasks(**options)
    expect(first[:task_ids].uniq.length).to eq(2)
    expect(replay[:task_ids]).to eq(first[:task_ids])
    expect(TASKER_SPEC_DB[:tasks].where(parent_id: fixture[:parent][:id]).count).to eq(2)
  end

  it 'rejects the entire fanout before inserting children when the configured bound is exceeded' do
    fixture = seed_relationship
    Legion::Settings.with_overlay(extensions: { tasker: { execution: { max_fanout: 1 } } }) do
      expect { runner.check_subtasks(**completion_options(fixture: fixture, results: [{ x: 1 }, { x: 2 }])) }.to raise_error(ArgumentError, /fanout/)
    end
    expect(TASKER_SPEC_DB[:tasks].where(parent_id: fixture[:parent][:id]).count).to eq(0)
  end

  it 'uses persisted depth so stale message metadata cannot bypass the chain bound' do
    fixture = seed_relationship
    Legion::Data::Model::Task[fixture[:parent][:id]].update(depth: 3)
    Legion::Settings.with_overlay(extensions: { tasker: { execution: { max_depth: 3 } } }) do
      expect { runner.check_subtasks(**completion_options(fixture: fixture, depth: 0)) }.to raise_error(ArgumentError, /depth/)
    end
  end

  it 'does not continue a cancelled parent even when completion is redelivered' do
    fixture = seed_relationship
    Legion::Data::Model::Task[fixture[:parent][:id]].update(cancelled_at: Time.now)
    expect(runner.check_subtasks(**completion_options(fixture: fixture))).to include(subtasks: 0, status: 'task.cancelled')
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(0)
  end

  it 'uses the earliest deadline and never continues an already expired envelope' do
    fixture = seed_relationship
    future = Time.now + 600
    Legion::Data::Model::Task[fixture[:parent][:id]].update(deadline_at: future)
    result = runner.check_subtasks(**completion_options(fixture: fixture, deadline_at: future + 60))
    expect(Legion::Data::Model::Task[result[:task_ids].first][:deadline_at]).to be_within(0.01).of(future)
    expect(runner.check_subtasks(**completion_options(fixture: fixture, deadline_at: Time.now - 1))).to include(subtasks: 0, status: 'task.expired')
  end
end
