# frozen_string_literal: true

require 'legion/transport/exchanges/task'
require 'legion/extensions/transport'
require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
      module Transport
        extend Legion::Extensions::Transport
        extend Legion::Transport::Task::Protocol::Helper

        def self.e_to_q
          [
            {
              to:          'updater',
              routing_key: task_route(name: :task_update)
            },
            {
              to:          'log',
              routing_key: 'task.logs.#'
            }, {
              to:          'check_subtask',
              routing_key: task_route(name: :check_subtask)
            }, {
              to:          'fetch_delayed',
              routing_key: 'fetch.delayed'
            }, {
              from:        'tasker',
              to:          'task_manager',
              routing_key: 'task.task_manager.#'
            }
          ]
        end
      end
    end
  end
end
