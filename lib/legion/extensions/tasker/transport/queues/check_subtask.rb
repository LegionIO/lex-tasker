module Legion::Extensions::Tasker
  module Transport
    module Queues
      class CheckSubtask < Legion::Transport::Queue
        def queue_name
          'task.subtask.check'
        end

        def queue_options
          {
            auto_delete: false,
            arguments:   { 'x-max-priority': 255 }
          }
        end
      end
    end
  end
end
