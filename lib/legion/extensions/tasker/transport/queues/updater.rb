module Legion::Extensions::Tasker
  module Transport
    module Queues
      class Updater < Legion::Transport::Queue
        def queue_name
          'task.updater'
        end
      end
    end
  end
end
