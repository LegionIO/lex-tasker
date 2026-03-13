# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Transport
        module Messages
          class FetchDelayed < Legion::Transport::Message
            def routing_key
              'fetch.delayed'
            end

            def expiration
              5000
            end
          end
        end
      end
    end
  end
end
