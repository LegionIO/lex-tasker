module Legion::Extensions::Tasker::Transport::Messages
  class FetchDelayed < Legion::Transport::Message
    def routing_key
      'fetch.delayed'
    end

    def exchange
      Legion::Transport::Exchanges::Task
    end

    def type
      'task'
    end

    def expiration
      5000
    end

    def message
      { test: 'foo' }
    end

    def validate
      @valid = true
    end
  end
end
