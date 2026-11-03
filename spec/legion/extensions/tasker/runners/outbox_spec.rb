# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'legion/extensions/tasker/runners/check_subtask'
require 'legion/extensions/tasker/runners/outbox'

RSpec.describe Legion::Extensions::Tasker::Runners::Outbox do
  subject(:runner) { described_class }
  let(:creator) { Legion::Extensions::Tasker::Runners::CheckSubtask }

  def bind_receiver(exchange:, tenant_id: nil)
    declaration = Legion::Transport::Exchange.declaration(name: exchange, tenant_id: tenant_id)
    channel = Legion::Transport::Connection.channel
    queue = channel.queue_declare_without_recording_topology("tasker-spec-#{SecureRandom.uuid}")
    queue.bind(declaration[:name], routing_key: '#')
    @queues ||= []
    @queues << queue
    queue
  end

  after { @queues&.each(&:delete) }

  it 'keeps an unroutable publication recoverable, then delivers the same child once a route exists' do
    fixture = seed_relationship
    child = creator.check_subtasks(**completion_options(fixture: fixture))[:task_ids].first
    expect(runner.dispatch_pending).to include(success: false, delivered: 0, released: 1)
    intent = TASKER_SPEC_DB[:task_dispatches].first
    expect(intent[:delivered_at]).to be_nil
    expect(intent[:token]).to be_nil

    received = Queue.new
    bind_receiver(exchange: 'example', tenant_id: 'tenant').subscribe(manual_ack: false) do |_delivery, _properties, body|
      received << Legion::JSON.load(body)
    end
    expect(runner.dispatch_pending).to include(success: true, delivered: 1, released: 0)
    body = Timeout.timeout(5) { received.pop }
    expect(body).to include(task_id: child, args: { value: 42 }, parent_id: fixture[:parent][:id], principal_id: 'principal')
    expect(runner.dispatch_pending).to include(delivered: 0)
    expect(TASKER_SPEC_DB[:task_dispatches].first[:delivered_at]).not_to be_nil
  end

  it 'relays persisted message types despite divergent local identity settings' do
    fixture = seed_relationship
    received = Queue.new
    %w[example task].each do |exchange|
      bind_receiver(exchange: exchange).subscribe(manual_ack: false) { |_delivery, _properties, body| received << Legion::JSON.load(body) }
    end
    %w[check_subtask subtask task dynamic transform].each do |type|
      options = { function_id: fixture[:action].id, function: 'consume', runner_class: 'Example::Target',
                  runner_routing_key: 'example.target.consume', args: { source: type }, results: { source: type },
                  transformation: '{}', engine: 'erb' }
      Legion::Data::TaskExecution.enqueue_dispatch(event_key: "map:#{type}", message_type: type, options: options)
    end

    Legion::Settings.with_overlay(task_execution: { message_types: { dynamic: 'local.dynamic', transform: 'local.transform' },
                                                    routes:        { transform: 'local.transform' },
                                                    outbox:        { statuses: { pending: 'local.pending', claimed: 'local.claimed' } } }) do
      expect(runner.dispatch_pending).to include(delivered: 5, released: 0)
    end
    bodies = Timeout.timeout(5) { Array.new(5) { received.pop } }
    expect(bodies.map { |body| body.dig(:args, :source) }).to contain_exactly('check_subtask', 'subtask', 'task', 'dynamic', 'transform')
  end

  it 'discards cancelled work without pretending it was published or repeatedly reclaiming it' do
    fixture = seed_relationship
    child = creator.check_subtasks(**completion_options(fixture: fixture))[:task_ids].first
    Legion::Data::Model::Task[fixture[:parent][:id]].update(cancelled_at: Time.now)

    expect(runner.dispatch_pending).to include(delivered: 0, released: 0, discarded: 1)
    intent = TASKER_SPEC_DB[:task_dispatches].first
    expect(intent[:delivered_at]).to be_nil
    expect(intent[:discard_reason]).to eq('task.cancelled')
    expect(Legion::Data::Model::Task[child][:status]).to eq('task.cancelled')
    expect(runner.dispatch_pending).to include(delivered: 0, discarded: 0)
  end

  it 'reclaims an expired relay lease without creating a second logical child' do
    fixture = seed_relationship
    creator.check_subtasks(**completion_options(fixture: fixture))
    Legion::Data::TaskExecution.claim_dispatches(owner: 'crashed', now: Time.now - 120)
    bind_receiver(exchange: 'example', tenant_id: 'tenant')

    expect(runner.dispatch_pending(owner: 'replacement')).to include(delivered: 1)
    expect(TASKER_SPEC_DB[:tasks].where(parent_id: fixture[:parent][:id]).count).to eq(1)
    expect(TASKER_SPEC_DB[:task_dispatches].first[:delivery_attempts]).to eq(2)
  end
end
