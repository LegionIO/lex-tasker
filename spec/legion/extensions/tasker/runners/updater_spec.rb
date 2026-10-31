# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/updater'

RSpec.describe Legion::Extensions::Tasker::Runners::Updater do
  subject(:runner) { described_class }

  it 'acknowledges a stale queued update without regressing completion or overwriting its result' do
    task = Legion::Data::TaskExecution.create_task(values: {}, idempotency_key: 'completed')[:task]
    claim = Legion::Data::TaskExecution.claim_task(task_id: task[:id], owner: 'worker')
    Legion::Data::TaskExecution.complete_task(task_id: task[:id], status: 'task.completed', result: { answer: 42 }, token: claim[:token])

    expect(runner.update_status(task_id: task[:id], status: 'task.queued', results: { answer: 'late' })).to include(success: true, changed: false)
    persisted = Legion::Data::Model::Task[task[:id]]
    expect(persisted[:status]).to eq('task.completed')
    expect(Legion::JSON.load(persisted[:results])).to eq(answer: 42)
  end

  it 'preserves JSON values and rejects a competing owner of a running task' do
    task = Legion::Data::TaskExecution.create_task(values: {}, idempotency_key: 'owned')[:task]
    expect(runner.update_status(task_id: task[:id], payload: { message: 'hello' }, function_args: { x: 1 })).to include(changed: true)
    persisted = Legion::Data::Model::Task[task[:id]]
    expect(Legion::JSON.load(persisted[:payload])).to eq(message: 'hello')
    expect(Legion::JSON.load(persisted[:function_args])).to eq(x: 1)
    Legion::Data::TaskExecution.claim_task(task_id: task[:id], owner: 'worker')
    expect(runner.update_status(task_id: task[:id], status: 'task.completed', token: 'different')).to include(changed: false)
    expect(persisted.refresh[:status]).to eq('task.running')
  end
end
