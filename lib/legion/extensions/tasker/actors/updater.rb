module Legion
  module Extensions
    module Tasker
      module Actor
        class Updater < Legion::Extensions::Actors::Subscription
          def runner_function
            'update_status'
          end
        end
      end
    end
  end
end
