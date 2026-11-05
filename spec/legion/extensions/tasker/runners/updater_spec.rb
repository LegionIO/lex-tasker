# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/updater'

RSpec.describe Legion::Extensions::Tasker::Runners::Updater do
  subject(:runner) { described_class }

  it 'updates the requested task status and serializes its result' do
    task = Legion::Data::Model::Task.create(status: 'task.running')
    other = Legion::Data::Model::Task.create(status: 'task.queued')

    expect(runner.update_status(task_id: task.id, status: 'task.completed', results: { answer: 42 }))
      .to include(success: true, changed: true, task_id: task.id)
    expect(task.refresh[:status]).to eq('task.completed')
    expect(Legion::JSON.load(task[:results])).to eq(answer: 42)
    expect(other.refresh[:status]).to eq('task.queued')
  end

  it 'preserves serialized JSON and updates payload and arguments on the same row' do
    task = Legion::Data::Model::Task.create(status: 'task.queued')
    payload = Legion::JSON.dump(message: 'hello')
    expect(runner.update_status(task_id: task.id, payload: payload, function_args: { x: 1 })).to include(changed: true)
    expect(task.refresh[:payload]).to eq(payload)
    expect(Legion::JSON.load(task[:function_args])).to eq(x: 1)
    expect(runner.update_status(task_id: task.id)).to include(success: true, changed: false)
  end

  it 'persists cancellation without an execution claim' do
    task = Legion::Data::Model::Task.create(status: 'task.delayed')
    now = Time.now
    runner.update_status(task_id: task.id, status: 'task.cancelled', cancelled_at: now)
    expect(task.refresh[:status]).to eq('task.cancelled')
    expect(task[:cancelled_at]).to be_within(0.01).of(now)
  end

  it 'reports a missing task without creating a replacement' do
    expect(runner.update_status(task_id: -1, status: 'task.completed')).to include(success: false, changed: false, reason: :missing)
  end

  it 'propagates a database update failure instead of reporting persistence success' do
    task = Legion::Data::Model::Task.create(status: 'task.running')
    TASKER_SPEC_DB.run("CREATE TRIGGER reject_task_update BEFORE UPDATE ON tasks BEGIN SELECT RAISE(FAIL, 'task update rejected'); END")
    expect { runner.update_status(task_id: task.id, status: 'task.completed') }.to raise_error(Sequel::DatabaseError, /task update rejected/)
  ensure
    TASKER_SPEC_DB.run('DROP TRIGGER IF EXISTS reject_task_update')
  end
end
