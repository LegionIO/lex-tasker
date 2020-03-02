require 'legion/transport/exchanges/task'
require 'legion/extensions/transport'

module Legion::Extensions::Tasker
  module Transport
    module AutoBuild
      extend Legion::Extensions::Transport
      def self.e_to_q
        [
          {
            from:        Legion::Transport::Exchanges::Task,
            to:          Legion::Extensions::Tasker::Transport::Queues::Updater,
            routing_key: 'task.update'
          },
          {
            from:        Legion::Transport::Exchanges::Task,
            to:          Legion::Extensions::Tasker::Transport::Queues::Log,
            routing_key: 'task.logs.#'
          }, {
            from:        Legion::Transport::Exchanges::Task,
            to:          Legion::Extensions::Tasker::Transport::Queues::CheckSubtask,
            routing_key: 'task.subtask.check'
          }, {
            from:        Legion::Transport::Exchanges::Task,
            to:          'fetch_delayed',
            routing_key: 'fetch.delayed'
          }
        ]
      end
    end
  end
end
