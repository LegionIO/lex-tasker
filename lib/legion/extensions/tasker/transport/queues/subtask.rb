module Legion::Extensions::Tasker
  module Transport
    module Queues
      class Subtask < Legion::Transport::Queue
        def queue_name
          'task.subtask'
        end
      end
    end
  end
end
