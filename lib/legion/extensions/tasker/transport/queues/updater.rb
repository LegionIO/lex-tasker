# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
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
  end
end
