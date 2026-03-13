# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Actor
        class Log < Legion::Extensions::Actors::Subscription
          def check_subtask?
            false
          end

          def generate_task?
            false
          end
        end
      end
    end
  end
end
