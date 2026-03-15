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
      class Task
        def self.where(*); self end
        def self.limit(n); self end
        def self.count; 0 end
        def self.any?; false end
        def self.delete; 0 end
      end unless defined?(Legion::Data::Model::Task)
    end
  end

  module Logging
    def self.debug(*); end
  end unless defined?(Legion::Logging)
end

# Stub Sequel for the date literal in purge_old
module Sequel
  def self.lit(str); str end
end unless defined?(Sequel)

require 'legion/extensions/tasker/runners/task_manager'

# rubocop:disable Metrics/BlockLength
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

    it 'uses default age of 31 days and limit of 100' do
      expect(Legion::Data::Model::Task).to receive(:where) do |arg|
        expect(arg).to include('31')
        dataset
      end
      expect(dataset).to receive(:limit).with(100).and_return(dataset)
      runner.purge_old
    end

    it 'uses provided age parameter' do
      expect(Legion::Data::Model::Task).to receive(:where) do |arg|
        expect(arg).to include('14')
        dataset
      end
      runner.purge_old(age: 14)
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
    it 'builds a dataset for queued statuses' do
      dataset = double('dataset')
      allow(dataset).to receive(:limit).and_return(dataset)
      expect(Legion::Data::Model::Task).to receive(:where).with(
        status: ['conditioner.queued', 'transformer.queued', 'task.queued']
      ).and_return(dataset)
      runner.expire_queued
    end

    it 'uses default limit of 10' do
      dataset = double('dataset')
      allow(Legion::Data::Model::Task).to receive(:where).and_return(dataset)
      expect(dataset).to receive(:limit).with(10).and_return(dataset)
      runner.expire_queued
    end
  end
end
# rubocop:enable Metrics/BlockLength
