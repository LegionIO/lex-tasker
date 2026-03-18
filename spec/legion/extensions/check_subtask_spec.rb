# frozen_string_literal: true

require 'spec_helper'

# Stub framework dependencies that check_subtask.rb requires at load time
module Legion
  module Transport
    module Messages
      class SubTask; end # rubocop:disable Lint/EmptyClass
    end
  end

  module Extensions
    module Helpers
      module Lex; end
    end

    module Tasker
      module Helpers
        module TaskFinder; end
      end

      module Runners
        module CheckSubtask; end
      end
    end
  end
end

# Stub the transport require that check_subtask.rb needs
$LOADED_FEATURES << 'legion/transport/messages/subtask'

require 'legion/extensions/tasker/runners/check_subtask'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'CheckSubtask pure logic' do
  let(:test_obj) do
    obj = Object.new
    obj.extend(Legion::Extensions::Tasker::Runners::CheckSubtask)
    obj
  end

  describe '#chain_matches?' do
    it 'returns true when allow_new_chains is true' do
      relationship = { allow_new_chains: true, chain_id: nil }
      expect(test_obj.chain_matches?(relationship, {})).to eq(true)
    end

    it 'returns true when chain_ids match' do
      relationship = { allow_new_chains: false, chain_id: 42 }
      opts = { chain_id: 42 }
      expect(test_obj.chain_matches?(relationship, opts)).to eq(true)
    end

    it 'returns false when chain_ids differ' do
      relationship = { allow_new_chains: false, chain_id: 42 }
      opts = { chain_id: 99 }
      expect(test_obj.chain_matches?(relationship, opts)).to eq(false)
    end

    it 'returns false when relationship has no chain_id' do
      relationship = { allow_new_chains: false, chain_id: nil }
      opts = { chain_id: 42 }
      expect(test_obj.chain_matches?(relationship, opts)).to eq(false)
    end

    it 'returns false when opts has no chain_id' do
      relationship = { allow_new_chains: false, chain_id: 42 }
      expect(test_obj.chain_matches?(relationship, {})).to eq(false)
    end
  end

  describe '#resolve_master_id' do
    it 'returns master_id when present' do
      expect(test_obj.resolve_master_id({ master_id: 10, parent_id: 20, task_id: 30 })).to eq(10)
    end

    it 'falls back to parent_id when master_id missing' do
      expect(test_obj.resolve_master_id({ parent_id: 20, task_id: 30 })).to eq(20)
    end

    it 'falls back to task_id when both missing' do
      expect(test_obj.resolve_master_id({ task_id: 30 })).to eq(30)
    end

    it 'returns nil when all are missing' do
      expect(test_obj.resolve_master_id({})).to be_nil
    end
  end

  describe '#subtask_routing_key' do
    it 'returns conditioner key when conditions present' do
      relationship = { conditions: '{"all":[{"fact":"x"}]}', transformation: nil, runner_routing_key: 'ext.runner.func' }
      expect(test_obj.subtask_routing_key(relationship)).to eq('task.subtask.conditioner')
    end

    it 'returns transformation key when transformation present but no conditions' do
      relationship = { conditions: nil, transformation: '{"key":"<%= val %>"}', runner_routing_key: 'ext.runner.func' }
      expect(test_obj.subtask_routing_key(relationship)).to eq('task.subtask.transformation')
    end

    it 'returns runner routing key when neither conditions nor transformation' do
      relationship = { conditions: nil, transformation: nil, runner_routing_key: 'ext.runner.func' }
      expect(test_obj.subtask_routing_key(relationship)).to eq('ext.runner.func')
    end

    it 'ignores short condition strings (< 5 chars)' do
      relationship = { conditions: '{}', transformation: nil, runner_routing_key: 'ext.runner.func' }
      expect(test_obj.subtask_routing_key(relationship)).to eq('ext.runner.func')
    end

    it 'ignores short transformation strings (< 5 chars)' do
      relationship = { conditions: nil, transformation: '{}', runner_routing_key: 'ext.runner.func' }
      expect(test_obj.subtask_routing_key(relationship)).to eq('ext.runner.func')
    end
  end

  describe '#resolve_results' do
    it 'returns results hash when present' do
      expect(test_obj.resolve_results({ results: { data: 1 } })).to eq({ data: 1 })
    end

    it 'falls back to result hash' do
      expect(test_obj.resolve_results({ result: { data: 2 } })).to eq({ data: 2 })
    end

    it 'returns full opts when neither results nor result is a hash' do
      opts = { foo: 'bar' }
      expect(test_obj.resolve_results(opts)).to eq(opts)
    end

    it 'prefers results over result' do
      expect(test_obj.resolve_results({ results: { a: 1 }, result: { b: 2 } })).to eq({ a: 1 })
    end
  end

  describe '#build_task_hash' do
    it 'sets status to conditioner.queued when delay is zero' do
      relationship = { delay: 0 }
      result = test_obj.build_task_hash(relationship, {})
      expect(result[:status]).to eq('conditioner.queued')
    end

    it 'sets status to task.delayed when delay is nonzero' do
      relationship = { delay: 30 }
      result = test_obj.build_task_hash(relationship, {})
      expect(result[:status]).to eq('task.delayed')
    end

    it 'sets parent_id from opts task_id' do
      relationship = { delay: 0 }
      result = test_obj.build_task_hash(relationship, { task_id: 42 })
      expect(result[:parent_id]).to eq(42)
    end

    it 'sets master_id using resolve_master_id' do
      relationship = { delay: 0 }
      result = test_obj.build_task_hash(relationship, { master_id: 10 })
      expect(result[:master_id]).to eq(10)
    end
  end
end
# rubocop:enable Metrics/BlockLength
