# frozen_string_literal: true

require 'legion/extensions/tasker/runners/outbox'

module Legion
  module Extensions
    module Tasker
      module Actor
        class Outbox < Legion::Extensions::Actors::Every
          def runner_function
            'dispatch_pending'
          end

          def runner_class
            Legion::Extensions::Tasker::Runners::Outbox
          end

          def time
            settings.fetch(:outbox).fetch(:poll_interval_seconds)
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def use_runner?
            false
          end
        end
      end
    end
  end
end
