module Legion::Extensions::Tasker::Transport::Messages
  class FetchDelayed < Legion::Transport::Message
    def routing_key
      'fetch.delayed'
    end

    def exchange
      Legion::Transport::Exchanges::Task
    end

    def expiration
      5000
    end
  end
end
