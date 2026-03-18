# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Actor
        class TaskManager < Legion::Extensions::Actors::Subscription
          def use_runner?
            true
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def prefetch
            1
          end
        end
      end
    end
  end
end
