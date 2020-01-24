module Legion
  module Extensions
    module Tasker
      module Actor
        class FetchDelayed < Legion::Extensions::Actors::Every
          def action
            'beat'
          end

          def time
            10
          end

          def klass
            Legion::Extensions::Tasker::Runners::FetchDelayed
          end
        end
      end
    end
  end
end
