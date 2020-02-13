module Legion::Extensions::Tasker
  module Actor
    class FetchDelayedPush < Legion::Extensions::Actors::Every
      def action
        'push'
      end

      def klass
        Legion::Extensions::Tasker::Runners::FetchDelayed
      end

      def use_runner
        false
      end

      def time
        5
      end
    end
  end
end
