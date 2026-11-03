# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/client'
require 'legion/extensions/tasker/runners/task_manager'

RSpec.describe Legion::Extensions::Tasker::Client do
  it 'finds persisted delayed work despite obsolete local status overrides' do
    fixture = seed_relationship
    task = Legion::Data::TaskExecution.create_task(values:          { function_id: fixture[:action].id, status: 'task.delayed' },
                                                   idempotency_key: 'canonical-delayed')[:task]
    Legion::Settings.with_overlay(task_execution: { statuses: { delayed: 'custom.delayed' } }) do
      expect(described_class.new.find_delayed.map { |row| row[:id] }.to_a).to eq([task[:id]])
    end
  end

  it 'preserves disabled queued recovery during client initialization and observes later policy changes' do
    now = Time.now
    task = Legion::Data::TaskExecution.create_task(values:          { created: now - 7200, status: 'task.queued' },
                                                   idempotency_key: 'disabled-recovery')[:task]
    Legion::Settings[:extensions][:tasker][:housekeeping][:queued_statuses] = []
    described_class.new
    manager = Legion::Extensions::Tasker::Runners::TaskManager

    expect(manager.expire_queued(now: now)).to include(expired: 0)
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('task.queued')

    Legion::Settings[:extensions][:tasker][:housekeeping][:queued_statuses] = [:queued]
    expect(manager.expire_queued(now: now)).to include(expired: 1)
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('task.expired')
  end
end
