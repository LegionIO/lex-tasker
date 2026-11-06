# frozen_string_literal: true

require 'legion/extensions/tasker'

module Legion
  module Extensions
    module Tasker
      module Transport
        module Queues
          class FetchDelayed < Legion::Transport::Queue
            include Legion::Settings::Helper

            def queue_name
              'task.fetch_delayed'
            end

            def queue_options
              {
                arguments: {
                  'x-single-active-consumer': true,
                  'x-message-ttl':            settings.fetch(:transport).fetch(:fetch_delayed_ttl_ms)
                }
              }
            end
          end
        end
      end
    end
  end
end
