module Legion
  module Extensions
    module Tasker
      module Actor
        class LexRegister < Legion::Extensions::Actors::Subscription
          def runner_function
            'save'
          end
        end
      end
    end
  end
end
