module Legion::Extensions::Tasker
  module Actor
    class FetchDelayed < Legion::Extensions::Actors::Subscription
      def runner_function
        'fetch'
      end
    end
  end
end
