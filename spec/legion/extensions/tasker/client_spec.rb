# frozen_string_literal: true

require 'spec_helper'

# Stub all framework dependencies before loading client
module Legion
  unless defined?(Legion::Cache)
    module Cache
      def self.get(_key) = nil
      def self.set(_key, _val, _ttl = nil); end
    end
  end

  unless defined?(Legion::Logging)
    module Logging
      def self.debug(*); end
    end
  end

  unless defined?(Legion::Data)
    module Data
      module Model
        unless defined?(Legion::Data::Model::Function)
          class Function
            def self.join(*) = self
            def self.where(*) = self
            def self.select(*) = self
            def self.first = nil
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

require 'legion/extensions/tasker/client'

RSpec.describe Legion::Extensions::Tasker::Client do
  let(:mock_model) do
    mod = Module.new
    mod
  end

  subject(:client) { described_class.new(data_model: mock_model) }

  describe '#initialize' do
    it 'creates a client with default data model (no injection)' do
      c = described_class.new
      expect(c.models_class).to eq(Legion::Data::Model)
    end

    it 'accepts an injected data model' do
      expect(client.models_class).to eq(mock_model)
    end

    it 'defaults data_model to nil' do
      c = described_class.new
      expect(c.instance_variable_get(:@data_model)).to be_nil
    end
  end

  describe '#models_class' do
    it 'returns the injected data model when provided' do
      expect(client.models_class).to eq(mock_model)
    end

    it 'returns Legion::Data::Model when no injection' do
      c = described_class.new
      expect(c.models_class).to eq(Legion::Data::Model)
    end
  end

  describe '#log' do
    it 'returns Legion::Logging when available' do
      expect(client.log).to eq(Legion::Logging)
    end

    it 'memoizes the log instance' do
      expect(client.log).to equal(client.log)
    end
  end

  describe '#settings' do
    it 'returns a hash with an options key' do
      expect(client.settings).to be_a(Hash)
      expect(client.settings).to have_key(:options)
    end

    it 'returns empty options hash' do
      expect(client.settings[:options]).to eq({})
    end
  end

  describe 'TaskFinder integration' do
    it 'responds to find_trigger' do
      expect(client).to respond_to(:find_trigger)
    end

    it 'responds to find_subtasks' do
      expect(client).to respond_to(:find_subtasks)
    end

    it 'responds to find_delayed' do
      expect(client).to respond_to(:find_delayed)
    end

    it 'includes Helpers::TaskFinder' do
      expect(described_class.ancestors).to include(Legion::Extensions::Tasker::Helpers::TaskFinder)
    end
  end

  describe '#find_trigger delegation' do
    it 'returns cached result when cache has value' do
      cached = { function_id: 1, runner_id: 2, namespace: 'MyRunner' }
      allow(Legion::Cache).to receive(:get).and_return(cached)
      result = client.find_trigger(runner_class: 'MyRunner', function: 'run')
      expect(result).to eq(cached)
    end

    it 'queries DB when cache empty' do
      allow(Legion::Cache).to receive(:get).and_return(nil)
      chain = double('chain')
      allow(Legion::Data::Model::Function).to receive(:join).and_return(chain)
      allow(chain).to receive(:where).and_return(chain)
      allow(chain).to receive(:select).and_return(chain)
      allow(chain).to receive(:first).and_return(nil)
      result = client.find_trigger(runner_class: 'Missing', function: 'nope')
      expect(result).to be_nil
    end
  end

  describe '#find_subtasks delegation' do
    it 'returns cached subtasks when available' do
      cached = [{ relationship_id: 1 }]
      allow(Legion::Cache).to receive(:get).and_return(cached)
      result = client.find_subtasks(trigger_id: 42)
      expect(result).to eq(cached)
    end

    it 'returns empty array when no subtasks found' do
      allow(Legion::Cache).to receive(:get).and_return(nil)
      chain = double('chain')
      allow(Legion::Data::Model::Relationship).to receive(:join).and_return(chain)
      allow(chain).to receive(:join).and_return(chain)
      allow(chain).to receive(:where).and_return(chain)
      allow(chain).to receive(:select).and_return(chain)
      allow(chain).to receive(:all).and_return([])
      result = client.find_subtasks(trigger_id: 99)
      expect(result).to eq([])
    end
  end

  describe '#find_delayed delegation' do
    it 'queries delayed tasks and returns array' do
      chain = double('chain')
      allow(Legion::Data::Model::Task).to receive(:join).and_return(chain)
      allow(chain).to receive(:join).and_return(chain)
      allow(chain).to receive(:left_join).and_return(chain)
      allow(chain).to receive(:where).and_return(chain)
      allow(chain).to receive(:select).and_return(chain)
      allow(chain).to receive(:all).and_return([])
      result = client.find_delayed
      expect(result).to eq([])
    end
  end
end
