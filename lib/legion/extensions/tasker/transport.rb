# frozen_string_literal: true

require 'legion/transport/exchanges/task'
require 'legion/extensions/transport'
require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
      module Transport
        extend Legion::Extensions::Transport
        extend Legion::Settings::Helper
        extend Legion::Transport::Task::Protocol::Helper

        def self.e_to_q
          [
            {
              to:          'updater',
              routing_key: task_route(name: :task_update)
            },
            {
              to:          'log',
              routing_key: settings.fetch(:transport).fetch(:log_route)
            }, {
              to:          'check_subtask',
              routing_key: task_route(name: :check_subtask)
            }, {
              to:          'fetch_delayed',
              routing_key: settings.fetch(:transport).fetch(:fetch_delayed_route)
            }, {
              from:        'tasker',
              to:          'task_manager',
              routing_key: settings.fetch(:transport).fetch(:task_manager_route)
            }
          ]
        end
      end
    end
  end
end
