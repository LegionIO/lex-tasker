module Legion
  module Extensions
    module Tasker
      module Actor
        class Log < Legion::Extensions::Actors::Subscription
          def runner_function
            'add_log'
          end
        end
      end
    end
  end
end
