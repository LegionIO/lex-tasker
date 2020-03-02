module Legion::Extensions::Tasker
  module Actor
    class Log < Legion::Extensions::Actors::Subscription
      def runner_function
        'add_log'
      end

      def use_runner
        false
      end
    end
  end
end
