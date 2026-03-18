# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Transport
    class Queue
      def queue_name; end
      def queue_options; {}; end
    end

    module Exchanges
      class Task; end
    end
  end
end

$LOADED_FEATURES << 'legion/transport/queue' unless $LOADED_FEATURES.include?('legion/transport/queue')
$LOADED_FEATURES << 'legion/transport/exchanges/task' unless $LOADED_FEATURES.include?('legion/transport/exchanges/task')

require 'legion/extensions/tasker/transport/queues/check_subtask'
require 'legion/extensions/tasker/transport/queues/subtask'
require 'legion/extensions/tasker/transport/queues/task_log'
require 'legion/extensions/tasker/transport/queues/task_mananger'
require 'legion/extensions/tasker/transport/queues/updater'
require 'legion/extensions/tasker/transport/queues/lex_register'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Tasker Transport Queues' do
  describe Legion::Extensions::Tasker::Transport::Queues::CheckSubtask do
    subject(:queue) { described_class.new }

    it 'sets queue name to task.subtask.check' do
      expect(queue.queue_name).to eq('task.subtask.check')
    end

    it 'sets auto_delete to false' do
      expect(queue.queue_options[:auto_delete]).to eq(false)
    end

    it 'includes arguments key in queue_options' do
      expect(queue.queue_options).to have_key(:arguments)
    end
  end

  describe Legion::Extensions::Tasker::Transport::Queues::Subtask do
    subject(:queue) { described_class.new }

    it 'sets queue name to task.subtask' do
      expect(queue.queue_name).to eq('task.subtask')
    end
  end

  describe Legion::Extensions::Tasker::Transport::Queues::Log do
    subject(:queue) { described_class.new }

    it 'sets queue name to task.log' do
      expect(queue.queue_name).to eq('task.log')
    end
  end

  describe Legion::Extensions::Tasker::Transport::Queues::TaskManager do
    subject(:queue) { described_class.new }

    it 'sets queue name to tasker.task_manager' do
      expect(queue.queue_name).to eq('tasker.task_manager')
    end

    it 'enables x-single-active-consumer' do
      sac = queue.queue_options.dig(:arguments, :'x-single-active-consumer')
      expect(sac).to eq(true)
    end
  end

  describe Legion::Extensions::Tasker::Transport::Queues::Updater do
    subject(:queue) { described_class.new }

    it 'sets queue name to task.updater' do
      expect(queue.queue_name).to eq('task.updater')
    end
  end

  describe Legion::Extensions::Tasker::Transport::Queues::LexRegister do
    subject(:queue) { described_class.new }

    it 'sets queue name to lex.register' do
      expect(queue.queue_name).to eq('lex.register')
    end

    it 'sets auto_delete to false' do
      expect(queue.queue_options[:auto_delete]).to eq(false)
    end
  end
end
# rubocop:enable Metrics/BlockLength
