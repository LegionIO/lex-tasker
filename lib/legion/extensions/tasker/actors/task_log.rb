module Legion
  module Extensions
    module Tasker
      module Actor
        class TaskLog < Legion::Extensions::Actors::Subscription
          def queue
            Legion::Extensions::Tasker::Transport::Queues::TaskLog
          end

          def class_path
            'legion/extensions/tasker/runners/task_log'
          end

          def runner_class
            Legion::Extensions::Tasker::Runners::TaskLog
          end

          def runner_method
            'add_log'
          end
        end
      end
    end
  end
end
