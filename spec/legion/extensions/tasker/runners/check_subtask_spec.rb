# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/check_subtask'

RSpec.describe Legion::Extensions::Tasker::Runners::CheckSubtask do
  subject(:runner) { described_class }

  before do
    @received = bind_task_receiver(exchange: 'example')
    @staged = bind_task_receiver(exchange: 'task')
  end

  it 'creates a real child row and publishes its target arguments and lineage' do
    fixture = seed_relationship
    result = runner.check_subtasks(**completion_options(fixture: fixture))

    expect(result).to include(success: true, subtasks: 1, created: 1)
    child = Legion::Data::Model::Task[result[:task_ids].first]
    message = Timeout.timeout(5) { @received.pop }
    expect(child.values).to include(parent_id: fixture[:parent][:id], master_id: fixture[:parent][:id], status: 'task.queued', depth: 1)
    expect(message).to include(task_id: child.id, args: { value: 42 }, results: { value: 42 }, function_args: { original: 'input' },
                               principal_id: 'principal', tenant_id: 'tenant', schema: { value: 'integer' }, engine_options: { strict: true })
  end

  it 'routes a short explicit transformation to the transformer stage' do
    fixture = seed_relationship(engine: 'erb', transformation: '{}')
    result = runner.check_subtasks(**completion_options(fixture: fixture))
    child = Legion::Data::Model::Task[result[:task_ids].first]
    message = Timeout.timeout(5) { @staged.pop }
    expect(child[:status]).to eq('transformer.queued')
    expect(message).to include(transformation: '{}', engine: 'erb')
    expect(Legion::JSON.load(child[:payload])[:options][:routing_key]).to eq('task.subtask.transform')
  end

  it 'conditions precede transformations while retaining the later stage template' do
    fixture = seed_relationship(conditions: '{"all":[]}', transformation: '{"ok":true}', engine: 'erb')
    result = runner.check_subtasks(**completion_options(fixture: fixture))
    expect(Legion::Data::Model::Task[result[:task_ids].first][:status]).to eq('conditioner.queued')
    message = Timeout.timeout(5) { @staged.pop }
    expect(message).to include(conditions: '{"all":[]}', transformation: '{"ok":true}')
    child = Legion::Data::Model::Task[result[:task_ids].first]
    expect(Legion::JSON.load(child[:payload])[:options][:routing_key]).to eq('task.subtask.conditioner')
  end

  it 'creates a distinct child for each fanout result' do
    fixture = seed_relationship
    options = completion_options(fixture: fixture, results: [{ value: 1 }, { value: 2 }])
    first = runner.check_subtasks(**options)
    expect(first[:task_ids].uniq.length).to eq(2)
    messages = Timeout.timeout(5) { Array.new(2) { @received.pop } }
    expect(messages.map { |message| message[:args] }).to contain_exactly({ value: 1 }, { value: 2 })
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
    expect(TASKER_SPEC_DB[:tasks].where(parent_id: fixture[:parent][:id]).count).to eq(0)
  end
end
