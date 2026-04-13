# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Extensions
    module Helpers
      module Task; end unless defined?(Legion::Extensions::Helpers::Task)
    end

    module Tasker
      module Helpers
        module TaskFinder; end unless defined?(Legion::Extensions::Tasker::Helpers::TaskFinder)
      end

      module Transport
        module Messages
          unless defined?(Legion::Extensions::Tasker::Transport::Messages::FetchDelayed)
            class FetchDelayed
              def initialize(**); end
              def publish; end
            end
          end
        end
      end
    end
  end

  module Transport
    module Messages
      unless defined?(Legion::Transport::Messages::Task)
        class Task
          def initialize(**); end
          def publish; end
        end
      end
    end
  end
end

require 'legion/extensions/tasker/runners/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Runners::FetchDelayed do
  let(:test_class) do
    Class.new do
      include Legion::Extensions::Tasker::Runners::FetchDelayed

      def log
        @log ||= Class.new { def debug(*); end }.new
      end

      def task_update(task_id, status); end
    end
  end

  subject { test_class.new }

  describe '#delayed_routing_key' do
    context 'when task has conditions' do
      it 'routes to conditioner' do
        task = { conditions: '{"all":[{"fact":"x","operator":"equal","value":1}]}', transformation: nil }
        expect(subject.delayed_routing_key(task)).to eq('task.subtask.conditioner')
      end
    end

    context 'when task has transformation but no conditions' do
      it 'routes to task.subtask.transform' do
        task = { conditions: nil, transformation: '{"template":"<%= results %>"}' }
        expect(subject.delayed_routing_key(task)).to eq('task.subtask.transform')
      end
    end

    context 'when task has neither conditions nor transformation' do
      it 'routes to the runner routing key' do
        task = { conditions: nil, transformation: nil, runner_routing_key: 'lex.developer.runners.developer.implement' }
        expect(subject.delayed_routing_key(task)).to eq('lex.developer.runners.developer.implement')
      end
    end
  end

  describe '#update_delayed_status' do
    it 'maps task.subtask.transform to transformer.queued' do
      allow(subject).to receive(:task_update)
      subject.update_delayed_status(1, 'task.subtask.transform')
      expect(subject).to have_received(:task_update).with(1, 'transformer.queued')
    end
  end
end
