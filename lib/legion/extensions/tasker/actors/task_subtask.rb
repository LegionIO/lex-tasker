module Legion
  module Extensions
    module Tasker
      module Actor
        class TaskSubtask < Legion::Extensions::Actors::Subscription
          def queue
            Legion::Extensions::Tasker::Transport::Queues::TaskSubtask
          end

          def class_path
            'legion/extensions/tasker/runners/task_subtask'
          end

          def runner_class
            Legion::Extensions::Tasker::Runners::TaskSubtask
          end

          def runner_method
            'check_subtasks'
          end

          def subscribe(manual_ack = true)
            require 'legion/extensions/tasker/runners/task_updater'
            @queue.subscribe(manual_ack: manual_ack) do |delivery_info, _metadata, payload|
              begin
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
end