# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/check_subtask'
require 'legion/extensions/tasker/runners/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Runners::FetchDelayed do
  subject(:runner) { described_class }
  let(:creator) { Legion::Extensions::Tasker::Runners::CheckSubtask }

  before do
    @received = bind_task_receiver(exchange: 'example')
    @staged = bind_task_receiver(exchange: 'task')
  end

  it 'replays the stored immediate envelope after delay, even if the relationship changes' do
    fixture = seed_relationship(conditions: '{"all":[]}', transformation: '{"ok":true}', engine: 'erb')
    options = completion_options(fixture: fixture)
    creator.check_subtasks(**options)
    immediate = Timeout.timeout(5) { @staged.pop }
    fixture[:relationship].update(delay: 30)
    another = Legion::Data::Model::Task.create(function_id: fixture[:trigger].id, status: 'task.completed').values
    delayed = creator.check_subtasks(**options, task_id: another[:id])
    child = Legion::Data::Model::Task[delayed[:task_ids].first]
    expect(child[:status]).to eq('task.delayed')
    expect(runner.fetch(now: child[:created] + 29)).to include(dispatched: 0)

    fixture[:relationship].update(conditions: nil, transformation: nil, engine: nil, delay: 600)
    expect(runner.fetch(now: child[:created] + 30)).to include(dispatched: 1)
    expect(runner.fetch(now: child[:created] + 31)).to include(dispatched: 0)
    stored = Timeout.timeout(5) { @staged.pop }
    expect(stored.except(:task_id, :parent_id, :master_id, :message_id, :created_at))
      .to eq(immediate.except(:task_id, :parent_id, :master_id, :message_id, :created_at))
    expect(child.refresh[:status]).to eq('conditioner.queued')
  end

  it 'propagates parent cancellation without cancelling the next parentless task' do
    fixture = seed_relationship(delay: 60)
    result = creator.check_subtasks(**completion_options(fixture: fixture))
    child = Legion::Data::Model::Task[result[:task_ids].first]
    independent = Legion::Data::Model::Task.create(status: 'task.delayed', function_id: child[:function_id],
                                                   task_delay: 0, payload: child[:payload])
    Legion::Data::Model::Task[fixture[:parent][:id]].update(cancelled_at: Time.now)
    expect(runner.fetch).to include(cancelled: 1, dispatched: 1)
    expect(Legion::Data::Model::Task[result[:task_ids].first][:status]).to eq('task.cancelled')
    expect(independent.refresh[:status]).to eq('task.queued')
  end

  it 'does not let an older long-delay task consume the eligible dispatch batch' do
    fixture = seed_relationship(delay: 3600)
    options = completion_options(fixture: fixture)
    waiting = creator.check_subtasks(**options)[:task_ids].first
    fixture[:relationship].update(delay: 1)
    another = Legion::Data::Model::Task.create(status: 'task.completed').values
    due = creator.check_subtasks(**options, task_id: another[:id])[:task_ids].first
    Legion::Settings.with_overlay(extensions: { tasker: { delayed_batch_size: 1 } }) do
      expect(runner.fetch(now: Time.now + 2)).to include(dispatched: 1)
    end
    expect(Timeout.timeout(5) { @received.pop }[:task_id]).to eq(due)
    expect(Legion::Data::Model::Task[waiting][:status]).to eq('task.delayed')
  end

  it 'leaves a rejected publication delayed and publishes it after its route is restored' do
    fixture = seed_relationship(delay: 1)
    result = creator.check_subtasks(**completion_options(fixture: fixture))
    child = Legion::Data::Model::Task[result[:task_ids].first]
    @tasker_queues.each(&:delete)
    @tasker_queues.clear

    expect { runner.fetch(now: child[:created] + 2) }.to raise_error(Legion::Transport::PublishRejected)
    expect(child.refresh[:status]).to eq('task.delayed')
    received = bind_task_receiver(exchange: 'example')
    expect(runner.fetch(now: child[:created] + 2)).to include(dispatched: 1)
    expect(Timeout.timeout(5) { received.pop }[:task_id]).to eq(child.id)
    expect(child.refresh[:status]).to eq('task.queued')
  end
end
