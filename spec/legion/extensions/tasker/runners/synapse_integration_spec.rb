# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/check_subtask'
require 'legion/extensions/tasker/runners/fetch_delayed'
require 'legion/extensions/tasker/runners/outbox'

RSpec.describe 'Optional synapse relationship integration' do
  let(:integration) { double('SynapseIntegration') }
  let(:runner) { Legion::Extensions::Tasker::Runners::CheckSubtask }
  let(:outbox) { Legion::Extensions::Tasker::Runners::Outbox }
  let(:message) { double('task message', publish!: { accepted: true }) }

  before do
    stub_const('Legion::Extensions::Synapse::Integration', integration)
    allow(integration).to receive(:attach_task)
    allow(integration).to receive(:evaluate_relationship).and_return(wrapped: true, allowed: true, result: { mapped: 7 }, signal_id: 123)
    allow(Legion::Transport::Messages::Dynamic).to receive(:new).and_return(message)
  end

  it 'persists evaluated output and attaches the signal before outbox publication' do
    fixture = seed_relationship(conditions: '{"all":[]}', transformation: '{"old":true}', engine: 'erb')
    result = runner.check_subtasks(**completion_options(fixture: fixture))
    child_id = result[:task_ids].first
    options = Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])
    expect(options).to include(args: { mapped: 7 }, results: { mapped: 7 }, task_id: child_id, synapse_signal_id: 123)
    expect(options).not_to have_key(:conditions)
    expect(options).not_to have_key(:transformation)
    expect(integration).not_to have_received(:attach_task)
    expect(integration).to receive(:attach_task).with(signal_id: 123, task_id: child_id, runner_class: 'Example::Target', function: 'consume').ordered
    expect(message).to receive(:publish!).ordered.and_return(accepted: true)
    expect(outbox.dispatch_pending).to include(delivered: 1)
    expect(Legion::Transport::Messages::Dynamic).to have_received(:new).with(hash_excluding(:synapse_signal_id))
  end

  it 'does not create a task or dispatch for a rejected evaluation' do
    fixture = seed_relationship
    allow(integration).to receive(:evaluate_relationship).and_return(wrapped: true, allowed: false)
    expect(runner.check_subtasks(**completion_options(fixture: fixture))).to include(subtasks: 0, created: 0)
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(0)
    expect(TASKER_SPEC_DB[:tasks].where(parent_id: fixture[:parent][:id]).count).to eq(0)
  end

  it 'retains the original rules for an unwrapped relationship' do
    fixture = seed_relationship(conditions: '{"all":[]}', transformation: '{}')
    allow(integration).to receive(:evaluate_relationship).and_return(wrapped: false)
    expect(runner.check_subtasks(**completion_options(fixture: fixture))).to include(created: 1)
    options = Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])
    expect(options).to include(conditions: '{"all":[]}', transformation: '{}')
    expect(options).not_to have_key(:synapse_signal_id)
  end

  it 'reuses a logical child on redelivery without recording another evaluation' do
    fixture = seed_relationship
    first = runner.check_subtasks(**completion_options(fixture: fixture))
    replay = runner.check_subtasks(**completion_options(fixture: fixture))
    expect(replay).to include(created: 0, task_ids: first[:task_ids])
    expect(integration).to have_received(:evaluate_relationship).once
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(1)
  end

  it 'persists signal correlation across delayed delivery without reevaluation' do
    fixture = seed_relationship(delay: 10)
    result = runner.check_subtasks(**completion_options(fixture: fixture))
    child = Legion::Data::Model::Task[result[:task_ids].first]
    expect(child[:status]).to eq('task.delayed')
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(0)
    Legion::Extensions::Tasker::Runners::FetchDelayed.fetch(now: child[:created] + 20)
    expect(outbox.dispatch_pending).to include(delivered: 1)
    expect(integration).to have_received(:evaluate_relationship).once
    expect(integration).to have_received(:attach_task).with(signal_id: 123, task_id: child.id, runner_class: 'Example::Target', function: 'consume')
  end

  it 'releases the durable intent without publishing if correlation fails' do
    fixture = seed_relationship
    runner.check_subtasks(**completion_options(fixture: fixture))
    allow(integration).to receive(:attach_task).and_raise(Sequel::DatabaseError, 'unavailable')
    expect(outbox.dispatch_pending).to include(delivered: 0, released: 1)
    expect(message).not_to have_received(:publish!)
    options = Legion::JSON.load(TASKER_SPEC_DB[:task_dispatches].first[:options])
    expect(options[:synapse_signal_id]).to eq(123)
  end

  it 'does not publish a correlated intent if the optional plugin is no longer loaded' do
    fixture = seed_relationship
    runner.check_subtasks(**completion_options(fixture: fixture))
    hide_const('Legion::Extensions::Synapse::Integration')
    expect(outbox.dispatch_pending).to include(delivered: 0, released: 1)
    expect(message).not_to have_received(:publish!)
  end

  it 'rejects non-Hash evaluated output before creating a child' do
    fixture = seed_relationship
    allow(integration).to receive(:evaluate_relationship).and_return(wrapped: true, allowed: true, result: 'invalid', signal_id: 123)
    expect { runner.check_subtasks(**completion_options(fixture: fixture)) }.to raise_error(ArgumentError, /Hash/)
    expect(TASKER_SPEC_DB[:task_dispatches].count).to eq(0)
  end
end
