# frozen_string_literal: true

require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class Subtask < Legion::Transport::Queue
            include Legion::Settings::Helper

            def queue_name
              settings.fetch(:transport).fetch(:subtask_queue)
            end
          end
        end
      end
    end
  end
end
