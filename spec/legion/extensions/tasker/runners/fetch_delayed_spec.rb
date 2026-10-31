# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/check_subtask'
require 'legion/extensions/tasker/runners/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Runners::FetchDelayed do
  subject(:runner) { described_class }
  let(:creator) { Legion::Extensions::Tasker::Runners::CheckSubtask }

  it 'replays the stored immediate envelope after delay, even if the relationship changes' do
    fixture = seed_relationship(conditions: '{"all":[]}', transformation: '{"ok":true}', engine: 'erb')
    options = completion_options(fixture: fixture)
    creator.check_subtasks(**options)
    immediate = Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])
    fixture[:relationship].update(delay: 30)
    another = Legion::Data::TaskExecution.create_task(values:          { function_id: fixture[:trigger].id, status: 'task.completed' },
                                                      idempotency_key: 'another-parent')[:task]
    delayed = creator.check_subtasks(**options, task_id: another[:id])
    child = Legion::Data::Model::Task[delayed[:task_ids].first]
    expect(child[:status]).to eq('task.delayed')
    expect(runner.fetch(now: child[:created] + 29)).to include(dispatched: 0)

    fixture[:relationship].update(conditions: nil, transformation: nil, engine: nil, delay: 600)
    expect(runner.fetch(now: child[:created] + 30)).to include(dispatched: 1)
    expect(runner.fetch(now: child[:created] + 31)).to include(dispatched: 0)
    persisted = TASKER_SPEC_DB[:task_dispatches].where(task_id: child.id).first
    stored = Legion::JSON.load(persisted[:options])
    expect(stored.except(:task_id, :parent_id, :master_id)).to eq(immediate.except(:task_id, :parent_id, :master_id))
    expect(persisted[:message_type]).to eq('subtask')
  end

  it 'expires a delayed task instead of dispatching it past its inherited deadline' do
    fixture = seed_relationship(delay: 60)
    result = creator.check_subtasks(**completion_options(fixture: fixture, deadline_at: Time.now + 30))
    child = Legion::Data::Model::Task[result[:task_ids].first]
    expect(runner.fetch(now: Time.now + 61)).to include(expired: 1, dispatched: 0)
    expect(child.refresh[:status]).to eq('task.expired')
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(0)
  end

  it 'propagates parent cancellation while a child is delayed' do
    fixture = seed_relationship(delay: 60)
    result = creator.check_subtasks(**completion_options(fixture: fixture))
    Legion::Data::Model::Task[fixture[:parent][:id]].update(cancelled_at: Time.now)
    expect(runner.fetch).to include(cancelled: 1, dispatched: 0)
    expect(Legion::Data::Model::Task[result[:task_ids].first][:status]).to eq('task.cancelled')
  end

  it 'does not let an older long-delay task consume the eligible dispatch batch' do
    fixture = seed_relationship(delay: 3600)
    options = completion_options(fixture: fixture)
    waiting = creator.check_subtasks(**options)[:task_ids].first
    fixture[:relationship].update(delay: 1)
    another = Legion::Data::TaskExecution.create_task(values: { status: 'task.completed' }, idempotency_key: 'second-parent')[:task]
    due = creator.check_subtasks(**options, task_id: another[:id])[:task_ids].first
    Legion::Settings.with_overlay(extensions: { tasker: { delayed_batch_size: 1 } }) do
      expect(runner.fetch(now: Time.now + 2)).to include(dispatched: 1)
    end
    expect(TASKER_SPEC_DB[:task_dispatches].get(:task_id)).to eq(due)
    expect(Legion::Data::Model::Task[waiting][:status]).to eq('task.delayed')
  end
end
