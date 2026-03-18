# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
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
                  'x-message-ttl':            1000
                }
              }
            end
          end
        end
      end
    end
  end
end
