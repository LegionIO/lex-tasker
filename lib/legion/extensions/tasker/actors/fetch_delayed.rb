module Legion::Extensions::Tasker
  module Actor
    class FetchDelayed < Legion::Extensions::Actors::Subscription
      def runner_function
        'fetch'
      end

      def use_runner?
        false
      end
    end
  end
end
