# frozen_string_literal: true

require 'spec_helper'

module Legion
  unless defined?(Legion::Cache)
    module Cache
      def self.get(_key) = nil
      def self.set(_key, _val, _ttl = nil); end
    end
  end

  module Data
    module Model
      unless defined?(Legion::Data::Model::Function)
        class Function
          def self.join(*) = self
          def self.where(*) = self
          def self.select(*) = self
          def self.first = nil
          def self.all = []
        end
      end

      unless defined?(Legion::Data::Model::Relationship)
        class Relationship
          def self.join(*) = self
          def self.where(*) = self
          def self.select(*) = self
          def self.all = []
        end
      end

      unless defined?(Legion::Data::Model::Task)
        class Task
          def self.join(*) = self
          def self.left_join(*) = self
          def self.where(*) = self
          def self.select(*) = self
          def self.all = []
        end
      end

      unless defined?(Legion::Data::Model::TaskLog)
        class TaskLog
          def self.insert(_hash) = 42
          def self.[](_id) = nil
          def self.where(*) = self
          def self.all = self
          def self.dataset = self
          def self.delete = 1
          def self.first = nil
        end
      end

      unless defined?(Legion::Data::Model::Node)
        class Node
          def self.where(*) = self
          def self.first = nil
        end
      end

      unless defined?(Legion::Data::Model::Runner)
        class Runner
          def self.where(*) = self
          def self.first = nil
          def self.values = nil
        end
      end
    end
  end
end

unless defined?(Sequel)
  module Sequel
    def self.[](table) = TableProxy.new(table)
    def self.lit(str, *) = str

    class TableProxy
      def initialize(table)
        @table = table
      end

      def [](col)
        ColumnProxy.new(@table, col)
      end
    end

    class ColumnProxy
      def initialize(table, col)
        @table = table
        @col = col
      end

      def as(alias_name)
        "#{@table}.#{@col} AS #{alias_name}"
      end

      def to_s
        "#{@table}.#{@col}"
      end
    end
  end
end

require 'legion/extensions/tasker/helpers/task_finder'

# rubocop:disable Metrics/BlockLength
RSpec.describe Legion::Extensions::Tasker::Helpers::TaskFinder do
  let(:finder) do
    obj = Object.new
    obj.extend(described_class)
    obj
  end

  describe '#find_trigger' do
    context 'when cache returns a result' do
      it 'returns the cached result without querying the DB' do
        cached_result = { function_id: 1, runner_id: 2, namespace: 'MyExt::Runners::MyRunner' }
        allow(finder).to receive(:cache_get).and_return(cached_result)
        expect(Legion::Data::Model::Function).not_to receive(:join)
        result = finder.find_trigger(runner_class: 'MyExt::Runners::MyRunner', function: 'run')
        expect(result).to eq(cached_result)
      end
    end

    context 'when cache is empty' do
      before { allow(finder).to receive(:cache_get).and_return(nil) }

      it 'queries the DB and caches the result' do
        db_result = { function_id: 5, runner_id: 3, namespace: 'SomeExt::Runners::Run' }
        chain = double('chain')
        allow(Legion::Data::Model::Function).to receive(:join).and_return(chain)
        allow(chain).to receive(:where).and_return(chain)
        allow(chain).to receive(:select).and_return(chain)
        allow(chain).to receive(:first).and_return(db_result)
        expect(finder).to receive(:cache_set).with(anything, db_result)
        result = finder.find_trigger(runner_class: 'SomeExt::Runners::Run', function: 'run')
        expect(result).to eq(db_result)
      end

      it 'returns nil without caching when DB returns nil' do
        chain = double('chain')
        allow(Legion::Data::Model::Function).to receive(:join).and_return(chain)
        allow(chain).to receive(:where).and_return(chain)
        allow(chain).to receive(:select).and_return(chain)
        allow(chain).to receive(:first).and_return(nil)
        expect(finder).not_to receive(:cache_set)
        result = finder.find_trigger(runner_class: 'Missing', function: 'missing')
        expect(result).to be_nil
      end
    end
  end

  describe '#find_subtasks' do
    context 'when cache returns a result' do
      it 'returns cached results without querying DB' do
        cached = [{ relationship_id: 1 }]
        allow(finder).to receive(:cache_get).and_return(cached)
        expect(Legion::Data::Model::Relationship).not_to receive(:join)
        result = finder.find_subtasks(trigger_id: 42)
        expect(result).to eq(cached)
      end
    end

    context 'when cache is empty' do
      before { allow(finder).to receive(:cache_get).and_return(nil) }

      it 'queries DB and adds runner_routing_key to each row' do
        row = { exchange: 'myext', queue: 'runner', function: 'run' }
        chain = double('chain')
        allow(Legion::Data::Model::Relationship).to receive(:join).and_return(chain)
        allow(chain).to receive(:join).and_return(chain)
        allow(chain).to receive(:where).and_return(chain)
        allow(chain).to receive(:select).and_return(chain)
        allow(chain).to receive(:all).and_return([row])
        allow(finder).to receive(:cache_set)
        result = finder.find_subtasks(trigger_id: 1)
        expect(result.first[:runner_routing_key]).to eq('myext.runner.run')
      end

      it 'caches results when non-empty array returned' do
        row = { exchange: 'ext', queue: 'q', function: 'fn' }
        chain = double('chain')
        allow(Legion::Data::Model::Relationship).to receive(:join).and_return(chain)
        allow(chain).to receive(:join).and_return(chain)
        allow(chain).to receive(:where).and_return(chain)
        allow(chain).to receive(:select).and_return(chain)
        allow(chain).to receive(:all).and_return([row])
        expect(finder).to receive(:cache_set).with(anything, anything, ttl: 5)
        finder.find_subtasks(trigger_id: 2)
      end

      it 'does not cache empty results' do
        chain = double('chain')
        allow(Legion::Data::Model::Relationship).to receive(:join).and_return(chain)
        allow(chain).to receive(:join).and_return(chain)
        allow(chain).to receive(:where).and_return(chain)
        allow(chain).to receive(:select).and_return(chain)
        allow(chain).to receive(:all).and_return([])
        expect(finder).not_to receive(:cache_set)
        result = finder.find_subtasks(trigger_id: 3)
        expect(result).to eq([])
      end
    end
  end

  describe '#find_delayed' do
    it 'queries delayed tasks and adds runner_routing_key' do
      task = { exchange: 'ext', queue: 'runner', function_name: 'process' }
      chain = double('chain')
      allow(Legion::Data::Model::Task).to receive(:join).and_return(chain)
      allow(chain).to receive(:join).and_return(chain)
      allow(chain).to receive(:left_join).and_return(chain)
      allow(chain).to receive(:where).and_return(chain)
      allow(chain).to receive(:select).and_return(chain)
      allow(chain).to receive(:all).and_return([task])
      result = finder.find_delayed
      expect(result.first[:runner_routing_key]).to eq('ext.runner.process')
    end

    it 'returns an empty array when no delayed tasks' do
      chain = double('chain')
      allow(Legion::Data::Model::Task).to receive(:join).and_return(chain)
      allow(chain).to receive(:join).and_return(chain)
      allow(chain).to receive(:left_join).and_return(chain)
      allow(chain).to receive(:where).and_return(chain)
      allow(chain).to receive(:select).and_return(chain)
      allow(chain).to receive(:all).and_return([])
      result = finder.find_delayed
      expect(result).to eq([])
    end
  end
end
# rubocop:enable Metrics/BlockLength
