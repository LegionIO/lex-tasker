module Legion::Extensions::Tasker
  module Actor
    class FetchDelayed < Legion::Extensions::Actors::Subscription
      def runner_function
        'fetch'
      end

      def runner_class
        Legion::Extensions::Tasker::Runners::FetchDelayed
      end

      def use_runner?
        false
      end

      def check_subtask?
        false
      end

      def generate_task?
        false
      end
    end
  end
end
