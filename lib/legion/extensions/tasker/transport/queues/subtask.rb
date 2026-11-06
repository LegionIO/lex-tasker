# frozen_string_literal: true

require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
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
  end
end
