# frozen_string_literal: true

require 'spec_helper'

# Stub base actor classes before loading actors
module Legion
  module Extensions
    unless defined?(Legion::Extensions::Actors)
      module Actors
        class Subscription
          def runner_function; end
          def check_subtask?; end
          def generate_task?; end
          def use_runner?; end
          def prefetch; end
        end

        class Every
          def runner_function; end
          def check_subtask?; end
          def generate_task?; end
          def use_runner?; end
          def time; end
        end
      end
    end

    module Tasker
      unless defined?(Legion::Extensions::Tasker::Runners)
        module Runners
          module FetchDelayed; end
        end
      end
    end
  end
end

$LOADED_FEATURES << 'legion/extensions/actors/subscription' unless $LOADED_FEATURES.include?('legion/extensions/actors/subscription')
$LOADED_FEATURES << 'legion/extensions/actors/every' unless $LOADED_FEATURES.include?('legion/extensions/actors/every')

require 'legion/extensions/tasker/actors/check_subtask'
require 'legion/extensions/tasker/actors/fetch_delayed'
require 'legion/extensions/tasker/actors/fetch_delayed_push'
require 'legion/extensions/tasker/actors/log'
require 'legion/extensions/tasker/actors/task_manager'
require 'legion/extensions/tasker/actors/updater'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Tasker Actors' do
  describe Legion::Extensions::Tasker::Actor::CheckSubtask do
    subject(:actor) { described_class.allocate }

    it 'is a subclass of Subscription' do
      expect(described_class.superclass).to eq(Legion::Extensions::Actors::Subscription)
    end

    it 'sets runner_function to check_subtasks' do
      expect(actor.runner_function).to eq('check_subtasks')
    end

    it 'returns false for check_subtask?' do
      expect(actor.check_subtask?).to eq(false)
    end

    it 'returns false for use_runner?' do
      expect(actor.use_runner?).to eq(false)
    end

    it 'returns false for generate_task?' do
      expect(actor.generate_task?).to eq(false)
    end
  end

  describe Legion::Extensions::Tasker::Actor::FetchDelayed do
    subject(:actor) { described_class.allocate }

    it 'is a subclass of Subscription' do
      expect(described_class.superclass).to eq(Legion::Extensions::Actors::Subscription)
    end

    it 'sets runner_function to fetch' do
      expect(actor.runner_function).to eq('fetch')
    end

    it 'sets runner_class to FetchDelayed runners module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Tasker::Runners::FetchDelayed)
    end

    it 'returns false for use_runner?' do
      expect(actor.use_runner?).to eq(false)
    end

    it 'returns false for check_subtask?' do
      expect(actor.check_subtask?).to eq(false)
    end

    it 'returns false for generate_task?' do
      expect(actor.generate_task?).to eq(false)
    end
  end

  describe Legion::Extensions::Tasker::Actor::FetchDelayedPush do
    subject(:actor) { described_class.allocate }

    it 'is a subclass of Every' do
      expect(described_class.superclass).to eq(Legion::Extensions::Actors::Every)
    end

    it 'sets runner_function to push' do
      expect(actor.runner_function).to eq('push')
    end

    it 'sets runner_class to FetchDelayed runners module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Tasker::Runners::FetchDelayed)
    end

    it 'returns false for check_subtask?' do
      expect(actor.check_subtask?).to eq(false)
    end

    it 'returns false for generate_task?' do
      expect(actor.generate_task?).to eq(false)
    end

    it 'returns false for use_runner?' do
      expect(actor.use_runner?).to eq(false)
    end

    it 'sets time to 1 (poll every 1 second)' do
      expect(actor.time).to eq(1)
    end
  end

  describe Legion::Extensions::Tasker::Actor::Log do
    subject(:actor) { described_class.allocate }

    it 'is a subclass of Subscription' do
      expect(described_class.superclass).to eq(Legion::Extensions::Actors::Subscription)
    end

    it 'returns false for check_subtask?' do
      expect(actor.check_subtask?).to eq(false)
    end

    it 'returns false for generate_task?' do
      expect(actor.generate_task?).to eq(false)
    end
  end

  describe Legion::Extensions::Tasker::Actor::TaskManager do
    subject(:actor) { described_class.allocate }

    it 'is a subclass of Subscription' do
      expect(described_class.superclass).to eq(Legion::Extensions::Actors::Subscription)
    end

    it 'returns true for use_runner?' do
      expect(actor.use_runner?).to eq(true)
    end

    it 'returns false for check_subtask?' do
      expect(actor.check_subtask?).to eq(false)
    end

    it 'returns false for generate_task?' do
      expect(actor.generate_task?).to eq(false)
    end

    it 'sets prefetch to 1' do
      expect(actor.prefetch).to eq(1)
    end
  end

  describe Legion::Extensions::Tasker::Actor::Updater do
    subject(:actor) { described_class.allocate }

    it 'is a subclass of Subscription' do
      expect(described_class.superclass).to eq(Legion::Extensions::Actors::Subscription)
    end

    it 'sets runner_function to update_status' do
      expect(actor.runner_function).to eq('update_status')
    end

    it 'returns false for check_subtask?' do
      expect(actor.check_subtask?).to eq(false)
    end

    it 'returns false for generate_task?' do
      expect(actor.generate_task?).to eq(false)
    end

    it 'returns false for use_runner?' do
      expect(actor.use_runner?).to eq(false)
    end
  end
end
# rubocop:enable Metrics/BlockLength
