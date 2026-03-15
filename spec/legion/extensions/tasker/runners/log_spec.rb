# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Legion
  module Extensions
    module Helpers
      module Lex; end unless defined?(Legion::Extensions::Helpers::Lex)
    end
  end

  module Data
    module Model
      class TaskLog
        def self.insert(hash); 42 end
        def self.[](id); nil end
        def self.where(*); self end
        def self.all; self end
        def self.delete; 1 end
        def self.first; nil end
      end unless defined?(TaskLog)

      class Node
        def self.where(*); self end
        def self.first; nil end
      end unless defined?(Node)

      class Runner
        def self.where(*); self end
        def self.first; nil end
        def self.values; nil end
      end unless defined?(Runner)
    end
  end unless defined?(Legion::Data)
end

require 'legion/extensions/tasker/runners/log'

# rubocop:disable Metrics/BlockLength
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
    it 'deletes all task log records' do
      all_records = double('all_records')
      allow(all_records).to receive(:delete).and_return(100)
      allow(Legion::Data::Model::TaskLog).to receive(:all).and_return(all_records)
      result = runner.delete_all
      expect(result).to include(success: true, count: 100)
    end

    it 'returns success: false when no records were deleted' do
      all_records = double('all_records')
      allow(all_records).to receive(:delete).and_return(0)
      allow(Legion::Data::Model::TaskLog).to receive(:all).and_return(all_records)
      result = runner.delete_all
      expect(result[:success]).to eq(false)
    end
  end
end
# rubocop:enable Metrics/BlockLength
