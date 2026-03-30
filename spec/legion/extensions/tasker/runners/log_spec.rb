# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Legion
  module Extensions
    module Helpers
      module Lex; end unless defined?(Legion::Extensions::Helpers::Lex)
    end
  end

  unless defined?(Legion::Data)
    module Data
      module Model
        unless defined?(TaskLog)
          class TaskLog
            def self.insert(_hash) = 42
            def self.[](_id) = nil
            def self.where(*) = self
            def self.all = self
            def self.delete = 1
            def self.first = nil
          end
        end

        unless defined?(Node)
          class Node
            def self.where(*) = self
            def self.first = nil
          end
        end

        unless defined?(Runner)
          class Runner
            def self.where(*) = self
            def self.first = nil
            def self.values = nil
          end
        end
      end
    end
  end
end

require 'legion/extensions/tasker/runners/log'

RSpec.describe Legion::Extensions::Tasker::Runners::Log do
  let(:runner) do
    klass = Class.new do
      include Legion::Extensions::Tasker::Runners::Log

      def log
        @log ||= Class.new { def debug(*); end }.new
      end
    end
    klass.new
  end

  describe '#add_log' do
    it 'inserts a task log record and returns success: true with the id' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert).and_return(42)
      result = runner.add_log(task_id: 1, entry: 'test message')
      expect(result).to include(success: true, id: 42)
    end

    it 'returns success: false when insert returns nil' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert).and_return(nil)
      result = runner.add_log(task_id: 1, entry: 'test message')
      expect(result[:success]).to eq(false)
    end

    it 'serializes non-string entry to JSON' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert) do |hash|
        expect(hash[:entry]).to be_a(String)
        1
      end
      runner.add_log(task_id: 1, entry: { key: 'val' })
    end

    it 'passes string entry through as-is' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert) do |hash|
        expect(hash[:entry]).to eq('plain string')
        1
      end
      runner.add_log(task_id: 1, entry: 'plain string')
    end

    it 'includes function_id in insert when provided' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert) do |hash|
        expect(hash[:function_id]).to eq(7)
        1
      end
      runner.add_log(task_id: 1, entry: 'log', function_id: 7)
    end

    it 'does not include node_id when neither node_id nor name provided' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert) do |hash|
        expect(hash).not_to have_key(:node_id)
        1
      end
      runner.add_log(task_id: 1, entry: 'log')
    end
  end

  describe '#delete_log' do
    it 'deletes the record and returns success: true when delete is positive' do
      record = double('task_log_record')
      allow(record).to receive(:delete).and_return(1)
      allow(Legion::Data::Model::TaskLog).to receive(:[]).with(5).and_return(record)
      result = runner.delete_log(id: 5)
      expect(result).to include(success: true, count: 1, deleted_id: 5)
    end

    it 'returns success: false when delete count is zero' do
      record = double('task_log_record')
      allow(record).to receive(:delete).and_return(0)
      allow(Legion::Data::Model::TaskLog).to receive(:[]).with(5).and_return(record)
      result = runner.delete_log(id: 5)
      expect(result[:success]).to eq(false)
    end
  end

  describe '#delete_task_logs' do
    it 'deletes all logs for the given task_id' do
      dataset = double('dataset')
      allow(dataset).to receive(:delete).and_return(3)
      allow(Legion::Data::Model::TaskLog).to receive(:where).with(task_id: 10).and_return(dataset)
      result = runner.delete_task_logs(task_id: 10)
      expect(result).to include(success: true, count: 3, deleted_task_id: 10)
    end

    it 'returns success: false when no records deleted' do
      dataset = double('dataset')
      allow(dataset).to receive(:delete).and_return(0)
      allow(Legion::Data::Model::TaskLog).to receive(:where).with(task_id: 99).and_return(dataset)
      result = runner.delete_task_logs(task_id: 99)
      expect(result[:success]).to eq(false)
    end
  end

  describe '#delete_node_logs' do
    it 'deletes all logs for the given node_id' do
      dataset = double('dataset')
      allow(dataset).to receive(:delete).and_return(5)
      allow(Legion::Data::Model::TaskLog).to receive(:where).with(node_id: 2).and_return(dataset)
      result = runner.delete_node_logs(node_id: 2)
      expect(result).to include(success: true, count: 5, deleted_node_id: 2)
    end
  end

  describe '#delete_all' do
    it 'deletes all task log records via dataset' do
      dataset = double('dataset')
      allow(dataset).to receive(:delete).and_return(100)
      allow(Legion::Data::Model::TaskLog).to receive(:dataset).and_return(dataset)
      result = runner.delete_all
      expect(result).to include(success: true, count: 100)
    end

    it 'returns success: false when no records were deleted' do
      dataset = double('dataset')
      allow(dataset).to receive(:delete).and_return(0)
      allow(Legion::Data::Model::TaskLog).to receive(:dataset).and_return(dataset)
      result = runner.delete_all
      expect(result[:success]).to eq(false)
    end
  end

  describe '#add_log with node_id in opts' do
    it 'uses opts[:node_id] not undefined payload variable' do
      allow(Legion::Data::Model::TaskLog).to receive(:insert) do |hash|
        expect(hash[:node_id]).to eq(7)
        42
      end
      runner.add_log(task_id: 1, entry: 'log', node_id: 7)
    end
  end

  describe '#add_log with name lookup' do
    it 'queries node by name and uses its id' do
      node = double('node', values: { id: 3 })
      allow(Legion::Data::Model::Node).to receive(:where).with(name: 'node-01').and_return(double(first: node))
      allow(Legion::Data::Model::TaskLog).to receive(:insert) do |hash|
        expect(hash[:node_id]).to eq(3)
        42
      end
      runner.add_log(task_id: 1, entry: 'log', name: 'node-01')
    end

    it 'handles nil node returned from name lookup' do
      allow(Legion::Data::Model::Node).to receive(:where).and_return(double(first: nil))
      allow(Legion::Data::Model::TaskLog).to receive(:insert).and_return(42)
      expect { runner.add_log(task_id: 1, entry: 'log', name: 'missing') }.not_to raise_error
    end
  end
end
