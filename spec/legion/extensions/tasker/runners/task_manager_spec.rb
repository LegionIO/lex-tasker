# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/task_manager'

RSpec.describe Legion::Extensions::Tasker::Runners::TaskManager do
  subject(:runner) { described_class }

  it 'expires only aged unowned queue work and leaves a completed result intact' do
    aged = Time.now - 7200
    queued = Legion::Data::TaskExecution.create_task(values: { created: aged, status: 'transformer.queued' }, idempotency_key: 'queued')[:task]
    complete = Legion::Data::TaskExecution.create_task(values: { created: aged, status: 'task.completed' }, idempotency_key: 'done')[:task]
    fresh = Legion::Data::TaskExecution.create_task(values: {}, idempotency_key: 'fresh')[:task]

    expect(runner.expire_queued).to include(expired: 1)
    expect(Legion::Data::Model::Task[queued[:id]][:status]).to eq('task.expired')
    expect(Legion::Data::Model::Task[complete[:id]][:status]).to eq('task.completed')
    expect(Legion::Data::Model::Task[fresh[:id]][:status]).to eq('task.queued')
  end

  it 'marks abandoned running effects unknown without claiming another attempt' do
    task = Legion::Data::TaskExecution.create_task(values: {}, idempotency_key: 'abandoned')[:task]
    Legion::Data::TaskExecution.claim_task(task_id: task[:id], owner: 'lost', now: Time.now - 120)
    expect(runner.recover_running).to include(unknown: 1)
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('task.unknown')
    expect(TASKER_SPEC_DB[:task_attempts].where(task_id: task[:id]).count).to eq(1)
    expect(Legion::Data::TaskExecution.claim_task(task_id: task[:id], owner: 'replacement')[:claimed]).to be(false)
  end

  it 'retains undelivered continuations despite divergent local task and dispatch status settings' do
    aged = Time.now - 7200
    pending = Legion::Data::TaskExecution.create_task(values: { created: aged, status: 'task.completed' }, idempotency_key: 'pending')[:task]
    deleted = Legion::Data::TaskExecution.create_task(values: { created: aged, status: 'task.completed' }, idempotency_key: 'delivered')[:task]
    Legion::Data::TaskExecution.enqueue_dispatch(event_key: 'pending-check', message_type: 'check_subtask', options: {}, task_id: pending[:id])

    Legion::Settings.with_overlay(task_execution: { statuses: { completed: 'local.completed' }, terminal_statuses: [],
                                                  outbox: { statuses: { pending: 'local.pending', claimed: 'local.claimed' } } },
                                  data:           { task_execution: { outbox: { statuses: { pending: 'other.pending', claimed: 'other.claimed' } } } }) do
      expect(runner.purge_old(age_seconds: 3600)).to include(deleted: 1)
    end
    expect(Legion::Data::Model::Task[pending[:id]]).not_to be_nil
    expect(Legion::Data::Model::Task[deleted[:id]]).to be_nil
    expect { runner.purge_old(status: 'task.running') }.to raise_error(ArgumentError, /terminal/)
  end
end
