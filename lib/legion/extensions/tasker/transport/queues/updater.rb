# frozen_string_literal: true

require 'legion/extensions/tasker'

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
