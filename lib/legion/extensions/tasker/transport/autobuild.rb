require 'legion/transport/exchanges/task'
require 'legion/extensions/transport/autobuild'

module Legion::Extensions::Tasker
  module Transport
    module AutoBuild
      extend Legion::Extensions::Transport::AutoBuild
      def self.e_to_q
        [
            {
                from:        Legion::Transport::Exchanges::Task,
                to:          Legion::Extensions::Tasker::Transport::Queues::TaskUpdate,
                routing_key: 'task.update'
            },
            {
                from:        Legion::Transport::Exchanges::Task,
                to:          Legion::Extensions::Tasker::Transport::Queues::TaskLog,
                routing_key: 'task.logs'
            }, {
                from:        Legion::Transport::Exchanges::Lex,
                to:          Legion::Extensions::Tasker::Transport::Queues::LexRegister,
                routing_key: 'lex.methods.register'
            }, {
                from:        Legion::Transport::Exchanges::Task,
                to:          Legion::Extensions::Tasker::Transport::Queues::TaskCheckSubtask,
                routing_key: 'task.subtask.check'
            }
        ]
      end
    end
  end
end
