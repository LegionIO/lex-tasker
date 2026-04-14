# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Extensions
    module Helpers
      module Lex; end unless defined?(Legion::Extensions::Helpers::Lex)
      module Task; end unless defined?(Legion::Extensions::Helpers::Task)
    end

    module Tasker
      module Helpers
        module TaskFinder; end unless defined?(Legion::Extensions::Tasker::Helpers::TaskFinder)
      end

      module Transport
        module Messages
          unless defined?(FetchDelayed)
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
      unless defined?(Task)
        class Task
          def initialize(**); end
          def publish; end
        end
      end
    end
  end

  unless defined?(Legion::Logging)
    module Logging
      def self.debug(*); end
    end
  end
end

require 'legion/extensions/tasker/runners/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Runners::FetchDelayed do
  let(:runner) do
    klass = Class.new do
      include Legion::Extensions::Tasker::Runners::FetchDelayed

      def log
        @log ||= Class.new { def debug(*); end }.new
      end

      def task_update(task_id, status); end
    end
    klass.new
  end

  describe '#delayed_by?' do
    it 'returns false when delay is zero' do
      expect(runner.delayed_by?(0, Time.now - 100)).to eq(false)
    end

    it 'returns false when delay is nil' do
      expect(runner.delayed_by?(nil, Time.now)).to eq(false)
    end

    it 'returns false when delay is not an Integer' do
      expect(runner.delayed_by?('60', Time.now)).to eq(false)
    end

    it 'returns true when delay has not elapsed' do
      # Created 10 seconds ago, delay is 30 seconds - still delayed
      expect(runner.delayed_by?(30, Time.now - 10)).to eq(true)
    end

    it 'returns false when delay has elapsed' do
      # Created 60 seconds ago, delay is 30 seconds - not delayed
      expect(runner.delayed_by?(30, Time.now - 60)).to eq(false)
    end
  end

  describe '#delayed_routing_key' do
    it 'returns conditioner key when conditions present' do
      task = { conditions: '{"all":[{"fact":"x"}]}', transformation: nil, runner_routing_key: 'ext.runner.func' }
      expect(runner.delayed_routing_key(task)).to eq('task.subtask.conditioner')
    end

    it 'returns transformation key when transformation present but no conditions' do
      task = { conditions: nil, transformation: '{"key":"<%= val %>"}', runner_routing_key: 'ext.runner.func' }
      expect(runner.delayed_routing_key(task)).to eq('task.subtask.transform')
    end

    it 'returns runner routing key when neither conditions nor transformation' do
      task = { conditions: nil, transformation: nil, runner_routing_key: 'ext.runner.func' }
      expect(runner.delayed_routing_key(task)).to eq('ext.runner.func')
    end

    it 'ignores short condition strings (< 5 chars)' do
      task = { conditions: '{}', transformation: nil, runner_routing_key: 'ext.runner.func' }
      expect(runner.delayed_routing_key(task)).to eq('ext.runner.func')
    end

    it 'prioritizes conditions over transformation' do
      task = {
        conditions:         '{"all":[{"fact":"x"}]}',
        transformation:     '{"key":"val"}',
        runner_routing_key: 'ext.runner.func'
      }
      expect(runner.delayed_routing_key(task)).to eq('task.subtask.conditioner')
    end
  end

  describe '#update_delayed_status' do
    it 'sets status to conditioner.queued for conditioner routing key' do
      expect(runner).to receive(:task_update).with(1, 'conditioner.queued')
      runner.update_delayed_status(1, 'task.subtask.conditioner')
    end

    it 'sets status to transformer.queued for transformation routing key' do
      expect(runner).to receive(:task_update).with(2, 'transformer.queued')
      runner.update_delayed_status(2, 'task.subtask.transform')
    end

    it 'sets status to task.queued for any other routing key' do
      expect(runner).to receive(:task_update).with(3, 'task.queued')
      runner.update_delayed_status(3, 'ext.runner.some_func')
    end
  end

  describe '#build_delayed_hash' do
    let(:task) do
      {
        id:                 10,
        relationship_id:    5,
        chain_id:           2,
        function_id:        3,
        function_name:      'process',
        runner_id:          1,
        runner_class:       'MyExt::Runners::MyRunner',
        runner_routing_key: 'ext.runner.process',
        exchange:           'ext',
        queue:              'runner',
        conditions:         nil,
        transformation:     nil
      }
    end

    it 'maps task fields to subtask hash' do
      result = runner.build_delayed_hash(task)
      expect(result[:task_id]).to eq(10)
      expect(result[:relationship_id]).to eq(5)
      expect(result[:function]).to eq('process')
    end

    it 'includes conditions when present as string' do
      task[:conditions] = '{"all":[]}'
      result = runner.build_delayed_hash(task)
      expect(result[:conditions]).to eq('{"all":[]}')
    end

    it 'excludes conditions when nil' do
      result = runner.build_delayed_hash(task)
      expect(result).not_to have_key(:conditions)
    end

    it 'includes transformation when present as string' do
      task[:transformation] = '{"key":"val"}'
      result = runner.build_delayed_hash(task)
      expect(result[:transformation]).to eq('{"key":"val"}')
    end

    it 'sets the routing_key from delayed_routing_key' do
      result = runner.build_delayed_hash(task)
      expect(result[:routing_key]).to eq('ext.runner.process')
    end
  end

  describe '#push' do
    it 'publishes a FetchDelayed message' do
      msg = instance_double(Legion::Extensions::Tasker::Transport::Messages::FetchDelayed, publish: nil)
      allow(Legion::Extensions::Tasker::Transport::Messages::FetchDelayed).to receive(:new).and_return(msg)
      result = runner.push
      expect(result).to include(success: true)
    end
  end

  describe '#send_task' do
    it 'publishes a Task message' do
      msg = instance_double(Legion::Transport::Messages::Task, publish: nil)
      allow(Legion::Transport::Messages::Task).to receive(:new).and_return(msg)
      runner.send_task(function: 'test', routing_key: 'ext.runner.test')
      expect(Legion::Transport::Messages::Task).to have_received(:new)
    end

    it 'copies result to results when result present but results not' do
      msg = instance_double(Legion::Transport::Messages::Task, publish: nil)
      allow(Legion::Transport::Messages::Task).to receive(:new) do |**opts|
        expect(opts[:results]).to eq({ data: 1 })
        msg
      end
      runner.send_task(result: { data: 1 }, function: 'test')
    end

    it 'defaults success to 1 when neither result nor success provided' do
      msg = instance_double(Legion::Transport::Messages::Task, publish: nil)
      allow(Legion::Transport::Messages::Task).to receive(:new) do |**opts|
        expect(opts[:success]).to eq(1)
        msg
      end
      runner.send_task(function: 'test')
    end
  end
end
