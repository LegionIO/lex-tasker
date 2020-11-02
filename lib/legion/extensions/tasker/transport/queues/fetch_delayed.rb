module Legion::Extensions::Tasker
  module Transport
    module Queues
      class FetchDelayed < Legion::Transport::Queue
        def queue_name
          'task.fetch_delayed'
        end

        def queue_options
          {
            arguments: {
              'x-single-active-consumer': true,
              'x-max-priority':           255,
              'x-message-ttl':            1
            }
          }
        end
      end
    end
  end
end
