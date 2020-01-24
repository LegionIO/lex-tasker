module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class TaskCheckSubtask < Legion::Transport::Queue
            def queue_name
              'task.subtask.check'
            end
          end
        end
      end
    end
  end
end
