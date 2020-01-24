module Legion
  module Extensions
    module Tasker
      module Actor
        class LexRegister < Legion::Extensions::Actors::Subscription
          def queue
            Legion::Extensions::Tasker::Transport::Queues::LexRegister
          end

          def class_path
            'legion/extensions/tasker/runners/lex_register'
          end

          def runner_class
            Legion::Extensions::Tasker::Runners::LexRegister
          end

          def runner_method
            'save'
          end
        end
      end
    end
  end
end
