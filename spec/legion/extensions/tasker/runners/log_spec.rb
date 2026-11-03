# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/runners/log'

RSpec.describe Legion::Extensions::Tasker::Runners::Log do
  subject(:runner) { described_class }

  it 'stores structured logs as Legion JSON and deletes a real model-backed entry' do
    fixture = seed_relationship
    result = runner.add_log(task_id: fixture[:parent][:id], entry: { action: 'started' }, runner_class: 'Example::Source', function: 'produce')
    entry = Legion::Data::Model::TaskLog[result[:id]]
    expect(Legion::JSON.load(entry[:entry])).to eq(action: 'started')
    expect(entry[:function_id]).to eq(fixture[:trigger].id)
    expect(runner.delete_log(id: entry.id)).to include(success: true, count: 1)
    expect(runner.delete_log(id: entry.id)).to include(success: false, count: 0)
  end

  it 'does not dereference a missing function during log attribution' do
    fixture = seed_relationship
    expect do
      runner.add_log(task_id: fixture[:parent][:id], entry: 'missing', runner_class: 'Example::Source', function: 'absent')
    end.to raise_error(ArgumentError, /function/)
    expect(Legion::Data::Model::TaskLog.count).to eq(0)
  end
end
