# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Actor
        class TaskManager < Legion::Extensions::Actors::Subscription
          trusted_internal true

          def use_runner?
            false
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def prefetch
            settings.fetch(:housekeeping).fetch(:prefetch)
          end
        end
      end
    end
  end
end
