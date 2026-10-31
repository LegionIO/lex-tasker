# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/client'

RSpec.describe Legion::Extensions::Tasker::Client do
  it 'finds persisted delayed work despite obsolete local status overrides' do
    fixture = seed_relationship
    task = Legion::Data::TaskExecution.create_task(values:          { function_id: fixture[:action].id, status: 'task.delayed' },
                                                   idempotency_key: 'canonical-delayed')[:task]
    Legion::Settings.with_overlay(task_execution: { statuses: { delayed: 'custom.delayed' } }) do
      expect(described_class.new.find_delayed.map { |row| row[:id] }.to_a).to eq([task[:id]])
    end
  end
end
