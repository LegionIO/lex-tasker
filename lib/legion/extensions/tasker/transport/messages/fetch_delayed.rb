# frozen_string_literal: true

require 'legion/extensions/tasker'
require 'legion/transport'

module Legion
  module Extensions
    module Tasker
      module Transport
        module Messages
          class FetchDelayed < Legion::Transport::Message
            include Legion::Settings::Helper

            def routing_key
              'fetch.delayed'
            end

            def expiration
              settings.fetch(:transport).fetch(:fetch_delayed_expiration_ms)
            end
          end
        end
      end
    end
  end
end
