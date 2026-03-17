# frozen_string_literal: true

require 'json'
require 'spec_helper'

module Legion
  module Extensions
    module Helpers
      module Lex; end unless defined?(Legion::Extensions::Helpers::Lex)
    end
  end

  unless defined?(Legion::Data)
    module Data
      module Model
        unless defined?(Task)
          class Task
            def self.[](_id) = nil
          end
        end
      end
    end
  end

  unless defined?(Legion::Logging)
    module Logging
      def self.unknown(*); end
    end
  end
end

require 'legion/extensions/tasker/runners/updater'

# rubocop:disable Metrics/BlockLength
RSpec.describe Legion::Extensions::Tasker::Runners::Updater do
  let(:runner) do
    klass = Class.new do
      include Legion::Extensions::Tasker::Runners::Updater

      def log
        @log ||= Class.new { def unknown(*); end }.new
      end

      def to_json(val)
        val.to_json
      end
    end
    klass.new
  end

  describe '#update_status' do
    context 'when task does not exist' do
      before { allow(Legion::Data::Model::Task).to receive(:[]).with(99).and_return(nil) }

      it 'returns success: false with message task nil' do
        result = runner.update_status(task_id: 99, status: 'task.completed')
        expect(result).to include(success: false, changed: false, task_id: 99, message: 'task nil')
      end
    end

    context 'when task record exists but values is nil' do
      let(:mock_task) do
        t = double('task')
        allow(t).to receive(:values).and_return(nil)
        allow(t).to receive(:class).and_return('Task')
        t
      end

      before { allow(Legion::Data::Model::Task).to receive(:[]).with(10).and_return(mock_task) }

      it 'returns success: false' do
        result = runner.update_status(task_id: 10, status: 'task.completed')
        expect(result[:success]).to eq(false)
      end
    end

    context 'when task exists with valid values' do
      let(:mock_task) do
        t = double('task')
        allow(t).to receive(:values).and_return({ id: 1, status: 'task.queued' })
        allow(t).to receive(:class).and_return('Task')
        allow(t).to receive(:update).and_return(true)
        t
      end

      before { allow(Legion::Data::Model::Task).to receive(:[]).with(1).and_return(mock_task) }

      it 'returns success: true and changed: true' do
        result = runner.update_status(task_id: 1, status: 'task.completed')
        expect(result).to include(success: true, changed: true, task_id: 1)
      end

      it 'calls update with the status' do
        expect(mock_task).to receive(:update).with(hash_including(status: 'task.completed'))
        runner.update_status(task_id: 1, status: 'task.completed')
      end

      it 'serializes non-string values to JSON' do
        expect(mock_task).to receive(:update) do |hash|
          expect(hash[:function_args]).to be_a(String)
          true
        end
        runner.update_status(task_id: 1, function_args: { key: 'val' })
      end

      it 'passes string values through as-is' do
        expect(mock_task).to receive(:update).with(hash_including(status: 'task.completed'))
        runner.update_status(task_id: 1, status: 'task.completed')
      end

      it 'includes updates in the return value' do
        allow(mock_task).to receive(:update)
        result = runner.update_status(task_id: 1, status: 'task.completed')
        expect(result[:updates]).to include(status: 'task.completed')
      end

      it 'ignores unknown columns' do
        expect(mock_task).to receive(:update).with(hash_not_including(unknown_col: 'x'))
        runner.update_status(task_id: 1, status: 'task.completed', unknown_col: 'x')
      end

      it 'updates results column' do
        expect(mock_task).to receive(:update).with(hash_including(results: anything))
        runner.update_status(task_id: 1, results: { data: 'result' })
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
