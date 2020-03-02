module Legion::Extensions::Tasker
  module Actor
    class FetchDelayedPush < Legion::Extensions::Actors::Every
      def runner_function
        'push'
      end

      def runner_class
        Legion::Extensions::Tasker::Runners::FetchDelayed
      end

      def use_runner
        false
      end

      def time
        1
      end
    end
  end
end
