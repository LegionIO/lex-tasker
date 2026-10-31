# frozen_string_literal: true

require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class TaskManager < Legion::Transport::Queue
            include Legion::Settings::Helper

            def queue_name
              settings.fetch(:transport).fetch(:task_manager_queue)
            end

            def queue_options
              { arguments: { 'x-single-active-consumer': true } }
            end
          end
        end
      end
    end
  end
end
