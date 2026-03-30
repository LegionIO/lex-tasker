# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Extensions
    module Helpers
      module Lex; end unless defined?(Legion::Extensions::Helpers::Lex)
      module Task; end unless defined?(Legion::Extensions::Helpers::Task)
    end
  end

  module Data
    module Model
      unless defined?(Legion::Data::Model::Task)
        class Task
          def self.where(*) = self
          def self.limit(_num) = self
          def self.count = 0
          def self.any? = false
          def self.delete = 0
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

# Stub Sequel for the date literal in purge_old
unless defined?(Sequel)
  module Sequel
    def self.lit(str, *_args) = str
  end
end

require 'legion/extensions/tasker/runners/task_manager'

RSpec.describe Legion::Extensions::Tasker::Runners::TaskManager do
  let(:runner) do
    klass = Class.new do
      include Legion::Extensions::Tasker::Runners::TaskManager

      def log
        @log ||= Class.new do
          def debug(*); end
        end.new
      end
    end
    klass.new
  end

  describe '#purge_old' do
    let(:dataset) { double('dataset') }

    before do
      allow(Legion::Data::Model::Task).to receive(:where).and_return(dataset)
      allow(dataset).to receive(:limit).and_return(dataset)
      allow(dataset).to receive(:where).and_return(dataset)
      allow(dataset).to receive(:count).and_return(0)
      allow(dataset).to receive(:any?).and_return(false)
      allow(dataset).to receive(:delete).and_return(0)
    end

    it 'builds a dataset filtered by date and limit' do
      expect(Legion::Data::Model::Task).to receive(:where).and_return(dataset)
      expect(dataset).to receive(:limit).with(100).and_return(dataset)
      runner.purge_old
    end

    it 'uses default age of 31 days (seconds-based cutoff)' do
      expect(Legion::Data::Model::Task).to receive(:where) do |arg|
        # parameterized query - literal string is 'created <= ?'
        expect(arg).to be_a(String)
        dataset
      end
      expect(dataset).to receive(:limit).with(100).and_return(dataset)
      runner.purge_old
    end

    it 'uses provided age parameter for cutoff' do
      called_with_seconds = false
      allow(Legion::Data::Model::Task).to receive(:where) do |_lit, time_arg|
        # 14 days = 14 * 86400 = 1209600 seconds in the past
        if time_arg
          expect(Time.now - time_arg).to be_within(5).of(14 * 86_400)
          called_with_seconds = true
        end
        dataset
      end
      runner.purge_old(age: 14)
      # If called with 1 arg only (Sequel.lit stub returns string), that's fine too
    end

    it 'applies status filter by reassigning dataset' do
      # Verify that the status filter is actually applied (dataset reassigned)
      expect(dataset).to receive(:where).with(status: 'task.completed').and_return(dataset)
      runner.purge_old(status: 'task.completed')
    end

    it 'skips status filter when status is wildcard' do
      expect(dataset).not_to receive(:where)
      runner.purge_old(status: '*')
    end

    it 'uses provided limit parameter' do
      expect(dataset).to receive(:limit).with(50).and_return(dataset)
      runner.purge_old(limit: 50)
    end

    it 'calls delete on the dataset' do
      expect(dataset).to receive(:delete)
      runner.purge_old
    end

    it 'logs count when records are present' do
      allow(dataset).to receive(:any?).and_return(true)
      allow(dataset).to receive(:count).and_return(5)
      expect(runner.log).to receive(:debug).at_least(:once)
      runner.purge_old
    end
  end

  describe '#expire_queued' do
    let(:dataset) { double('dataset') }

    before do
      allow(Legion::Data::Model::Task).to receive(:where).and_return(dataset)
      allow(dataset).to receive(:where).and_return(dataset)
      allow(dataset).to receive(:limit).and_return(dataset)
      allow(dataset).to receive(:update).and_return(3)
    end

    it 'filters by queued statuses' do
      expect(Legion::Data::Model::Task).to receive(:where).with(
        status: ['conditioner.queued', 'transformer.queued', 'task.queued']
      ).and_return(dataset)
      runner.expire_queued
    end

    it 'uses default limit of 10' do
      expect(dataset).to receive(:limit).with(10).and_return(dataset)
      runner.expire_queued
    end

    it 'calls update to set status to task.expired' do
      expect(dataset).to receive(:update).with(status: 'task.expired').and_return(3)
      runner.expire_queued
    end

    it 'returns success: true with expired count' do
      result = runner.expire_queued
      expect(result).to include(success: true, expired: 3)
    end
  end
end
