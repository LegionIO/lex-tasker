# frozen_string_literal: true

require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class CheckSubtask < Legion::Transport::Queue
            include Legion::Transport::TaskProtocol::Helper

            def queue_name
              task_route(name: :check_subtask)
            end

            def queue_options
              {
                auto_delete: false,
                arguments:   {}
              }
            end
          end
        end
      end
    end
  end
end
