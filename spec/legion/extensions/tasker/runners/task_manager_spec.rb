# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/task_manager'

RSpec.describe Legion::Extensions::Tasker::Runners::TaskManager do
  subject(:runner) { described_class }

  it 'creates one task with serialized arguments and payload' do
    result = nil
    expect do
      result = runner.generate_task_id(function_id: nil, args: { value: 42 }, payload: { source: 'message' })
    end.to change(Legion::Data::Model::Task, :count).by(1)
    task = Legion::Data::Model::Task[result[:task_id]]
    expect(result).to include(success: true, task_id: task.id)
    expect(Legion::JSON.load(task[:function_args])).to eq(value: 42)
    expect(Legion::JSON.load(task[:payload])).to eq(source: 'message')
  end

  it 'preserves already serialized arguments and payload without encoding them twice' do
    result = runner.generate_task_id(function_id: nil, args: '{"value":42}', payload: '{"source":"message"}')
    task = Legion::Data::Model::Task[result[:task_id]]
    expect(Legion::JSON.load(task[:function_args])).to eq(value: 42)
    expect(Legion::JSON.load(task[:payload])).to eq(source: 'message')
  end

  it 'propagates database insert failures to the persistence consumer' do
    TASKER_SPEC_DB.run("CREATE TRIGGER reject_task_insert BEFORE INSERT ON tasks BEGIN SELECT RAISE(FAIL, 'task write rejected'); END")
    expect { runner.generate_task_id(function_id: nil) }.to raise_error(Sequel::DatabaseError, /task write rejected/)
  ensure
    TASKER_SPEC_DB.run('DROP TRIGGER IF EXISTS reject_task_insert')
  end

  it 'expires only aged queued work and leaves completed and fresh tasks intact' do
    aged = Time.now - 7200
    queued = Legion::Data::Model::Task.create(created: aged, status: 'transformer.queued')
    complete = Legion::Data::Model::Task.create(created: aged, status: 'task.completed')
    fresh = Legion::Data::Model::Task.create(status: 'task.queued')

    expect(runner.expire_queued).to include(expired: 1)
    expect(queued.refresh[:status]).to eq('task.expired')
    expect(complete.refresh[:status]).to eq('task.completed')
    expect(fresh.refresh[:status]).to eq('task.queued')
  end

  it 'does not expire a task that completes after queued work is selected' do
    first = Legion::Data::Model::Task.create(created: Time.now - 7200, status: 'task.queued')
    second = Legion::Data::Model::Task.create(created: Time.now - 7200, status: 'task.queued')
    TASKER_SPEC_DB.run("CREATE TRIGGER complete_selected AFTER UPDATE ON tasks WHEN NEW.id = #{first.id} AND NEW.status = 'task.expired' " \
                       "BEGIN UPDATE tasks SET status = 'task.completed' WHERE id = #{second.id}; END")
    expect(runner.expire_queued).to include(expired: 1, cancelled: 0)
    expect(first.refresh[:status]).to eq('task.expired')
    expect(second.refresh[:status]).to eq('task.completed')
  ensure
    TASKER_SPEC_DB.run('DROP TRIGGER IF EXISTS complete_selected')
  end

  it 'purges aged terminal tasks without removing active or recent work' do
    aged = Time.now - 7200
    deleted = Legion::Data::Model::Task.create(created: aged, status: 'task.completed')
    active = Legion::Data::Model::Task.create(created: aged, status: 'task.running')
    recent = Legion::Data::Model::Task.create(status: 'task.completed')

    expect(runner.purge_old(age_seconds: 3600)).to include(deleted: 1)
    expect(Legion::Data::Model::Task[deleted.id]).to be_nil
    expect(Legion::Data::Model::Task[active.id]).not_to be_nil
    expect(Legion::Data::Model::Task[recent.id]).not_to be_nil
    expect { runner.purge_old(status: 'task.running') }.to raise_error(ArgumentError, /terminal/)
  end
end
