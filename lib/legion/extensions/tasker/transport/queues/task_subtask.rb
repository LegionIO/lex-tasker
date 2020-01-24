module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class TaskSubtask < Legion::Transport::Queue
            def queue_name
              'task.subtask'
            end
          end
        end
      end
    end
  end
end
