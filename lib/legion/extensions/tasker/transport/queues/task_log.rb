module Legion::Extensions::Tasker
  module Transport
    module Queues
      class Log < Legion::Transport::Queue
        def queue_name
          'task.log'
        end
      end
    end
  end
end
