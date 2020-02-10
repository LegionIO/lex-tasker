module Legion
  module Extensions
    module Tasker
      module Actor
        class Subtask < Legion::Extensions::Actors::Subscription
          def runner_function
            'check_subtasks'
          end

          def subscribe(manual_ack = true)
            @queue.subscribe(manual_ack: manual_ack) do |delivery_info, _metadata, payload|
              message = Legion::JSON.load(payload)
              Legion::Extensions::Tasker::Runners::TaskSubtask.check_subtasks(message[:args])
              @queue.acknowledge(delivery_info.delivery_tag) if manual_ack
            rescue StandardError => e
              Legion::Logging.error(e.message)
              Legion::Logging.error(e.backtrace)
              @queue.reject(delivery_info.delivery_tag) if manual_ack
            end
          end
        end
      end
    end
  end
end
