module Legion::Extensions::Tasker
  module Transport
    module Queues
      class LexRegister < Legion::Transport::Queue
        def queue_name
          'lex.register'
        end

        def queue_options
          { auto_delete: false }
        end
      end
    end
  end
end
