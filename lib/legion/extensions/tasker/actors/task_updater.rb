module Legion
  module Extensions
    module Tasker
      module Actor
        class TaskUpdater < Legion::Extensions::Actors::Subscription
          def queue
            Legion::Extensions::Tasker::Transport::Queues::TaskUpdate
          end

          def class_path
            'legion/extensions/tasker/runners/task_updater'
          end

          def runner_class
            Legion::Extensions::Tasker::Runners::TaskUpdater
          end

          def runner_method
            'update_status'
          end
        end
      end
    end
  end
end
