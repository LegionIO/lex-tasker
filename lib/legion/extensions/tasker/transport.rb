require 'legion/transport/exchanges/task'
require 'legion/extensions/transport'

module Legion::Extensions::Tasker
  module Transport
    extend Legion::Extensions::Transport
    def self.e_to_q
      [
        {
          to:          'updater',
          routing_key: 'task.update'
        },
        {
          to:          'log',
          routing_key: 'task.logs.#'
        }, {
          to:          'check_subtask',
          routing_key: 'task.subtask.check'
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
