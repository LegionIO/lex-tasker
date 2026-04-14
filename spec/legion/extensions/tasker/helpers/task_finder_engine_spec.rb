# frozen_string_literal: true

require 'spec_helper'
require 'sequel'
require 'legion/extensions/tasker/helpers/task_finder'

RSpec.describe Legion::Extensions::Tasker::Helpers::TaskFinder do
  let(:test_class) do
    Class.new do
      include Legion::Extensions::Tasker::Helpers::TaskFinder

      def cache_connected?
        false
      end
    end
  end

  subject { test_class.new }

  describe '#subtask_query result includes engine' do
    before do
      # Create in-memory DB with needed tables
      @db = Sequel.sqlite
      @db.create_table(:extensions) do
        primary_key :id
        String :exchange
      end
      @db.create_table(:runners) do
        primary_key :id
        foreign_key :extension_id, :extensions
        String :namespace
        String :queue
      end
      @db.create_table(:functions) do
        primary_key :id
        foreign_key :runner_id, :runners
        String :name
      end
      @db.create_table(:relationships) do
        primary_key :id
        foreign_key :trigger_id, :functions
        foreign_key :action_id, :functions
        TrueClass :active, default: true
        TrueClass :debug, default: false
        TrueClass :allow_new_chains, default: false
        Integer :delay, default: 0
        Integer :chain_id
        String :conditions, text: true
        String :transformation, text: true
        String :engine, size: 50
      end

      # Seed data
      ext_id = @db[:extensions].insert(exchange: 'lex.transformer')
      runner_id = @db[:runners].insert(extension_id: ext_id, namespace: 'Transform', queue: 'runners.transform')
      trigger_fn_id = @db[:functions].insert(runner_id: runner_id, name: 'assess')
      action_fn_id = @db[:functions].insert(runner_id: runner_id, name: 'transform')

      @db[:relationships].insert(
        trigger_id:     trigger_fn_id,
        action_id:      action_fn_id,
        active:         true,
        engine:         'llm',
        transformation: '{"prompt":"summarize feedback"}'
      )

      stub_const('Legion::Data::Model::Relationship', @db[:relationships])
    end

    it 'includes engine in the finder result' do
      trigger_row = @db[:functions].first
      result = subject.find_subtasks(trigger_id: trigger_row[:id])
      expect(result.first).to have_key(:engine)
      expect(result.first[:engine]).to eq('llm')
    end
  end
end
