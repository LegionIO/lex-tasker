# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/client'
require 'legion/extensions/tasker/runners/task_manager'

RSpec.describe Legion::Extensions::Tasker::Client do
  it 'returns delayed task rows as plain hashes' do
    fixture = seed_relationship
    task = Legion::Data::Model::Task.create(function_id: fixture[:action].id, status: 'task.delayed')
    expect(described_class.new.find_delayed.to_a).to eq([task.values])
  end

  it 'preserves disabled queued recovery during client initialization and observes later policy changes' do
    now = Time.now
    task = Legion::Data::Model::Task.create(created: now - 7200, status: 'task.queued').values
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
