# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
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
  end
end
