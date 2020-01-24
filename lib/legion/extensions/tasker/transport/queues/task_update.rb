module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class TaskUpdate < Legion::Transport::Queue
            def queue_name
              'task.update'
            end

            def queue_options
              hash = {}
              hash[:manual_ack] = true
              hash[:durable] = true
              hash[:exclusive] = false
              hash[:block] = false
              hash[:arguments] = { 'x-max-priority': 252, 'x-dead-letter-exchange': 'task.dlx', 'x-single-active-consumer': true }
              hash
            end
          end
        end
      end
    end
  end
end
