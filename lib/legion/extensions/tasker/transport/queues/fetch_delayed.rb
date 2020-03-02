module Legion::Extensions::Tasker
  module Transport
    module Queues
      class FetchDelayed < Legion::Transport::Queue
        def queue_name
          'task.fetch_delayed'
        end
      end
    end
  end
end
