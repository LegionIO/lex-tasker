# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/client'

RSpec.describe Legion::Extensions::Tasker::Client do
  it 'uses the real shared settings overlay without replacing deployment overrides' do
    fixture = seed_relationship
    Legion::Settings.with_overlay(task_execution: { statuses: { delayed: 'custom.delayed' } }) do
      task = Legion::Data::TaskExecution.create_task(values:          { function_id: fixture[:action].id, status: 'custom.delayed' },
                                                     idempotency_key: 'custom-delayed')[:task]
      expect(described_class.new.find_delayed.map { |row| row[:id] }.to_a).to eq([task[:id]])
    end
  end
end
