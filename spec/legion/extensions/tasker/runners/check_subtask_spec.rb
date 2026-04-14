# frozen_string_literal: true

require 'spec_helper'

# Stub transport dependency required at load time by check_subtask.rb
$LOADED_FEATURES << 'legion/transport/messages/subtask' unless $LOADED_FEATURES.include?('legion/transport/messages/subtask')

module Legion
  module Extensions
    module Tasker
      module Helpers
        module TaskFinder; end unless defined?(Legion::Extensions::Tasker::Helpers::TaskFinder)
      end
    end
  end
end

require 'legion/extensions/tasker/runners/check_subtask'

RSpec.describe Legion::Extensions::Tasker::Runners::CheckSubtask do
  let(:test_class) do
    Class.new do
      include Legion::Extensions::Tasker::Runners::CheckSubtask
    end
  end

  subject { test_class.new }

  describe '#subtask_routing_key' do
    context 'when relationship has conditions' do
      it 'routes to conditioner' do
        relationship = { conditions: '{"all":[{"fact":"x","operator":"equal","value":1}]}', transformation: nil }
        expect(subject.subtask_routing_key(relationship)).to eq('task.subtask.conditioner')
      end
    end

    context 'when relationship has transformation but no conditions' do
      it 'routes to task.subtask.transform' do
        relationship = { conditions: nil, transformation: '{"template":"<%= results %>"}' }
        expect(subject.subtask_routing_key(relationship)).to eq('task.subtask.transform')
      end
    end

    context 'when relationship has neither conditions nor transformation' do
      it 'routes to the runner routing key' do
        relationship = { conditions: nil, transformation: nil, runner_routing_key: 'lex.planner.runners.planner.plan' }
        expect(subject.subtask_routing_key(relationship)).to eq('lex.planner.runners.planner.plan')
      end
    end
  end
end
