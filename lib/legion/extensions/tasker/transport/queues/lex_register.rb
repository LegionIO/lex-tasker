module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class LexRegister < Legion::Transport::Queue
            def queue_name
              'lex.register'
            end
          end
        end
      end
    end
  end
end
