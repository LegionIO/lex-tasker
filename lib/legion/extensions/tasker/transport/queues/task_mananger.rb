module Legion::Extensions::Tasker
  module Transport
    module Queues
      class TaskManager < Legion::Transport::Queue
        def queue_name
          'tasker.task_manager'
        end

        def queue_options
          { arguments: { 'x-single-active-consumer': true } }
        end
      end
    end
  end
end
