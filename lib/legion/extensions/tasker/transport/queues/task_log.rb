module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class TaskLog < Legion::Transport::Queue
            def queue_name
              'task.log'
            end

            def queue_options
              hash = {}
              hash[:manual_ack] = true
              hash[:durable] = true
              hash[:exclusive] = false
              hash[:block] = false
              hash[:arguments] = {}
              hash
            end
          end
        end
      end
    end
  end
end
