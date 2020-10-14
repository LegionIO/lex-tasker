module Legion::Extensions::Tasker
  module Actor
    class Updater < Legion::Extensions::Actors::Subscription
      def runner_function
        'update_status'
      end

      def check_subtask?
        false
      end

      def generate_task?
        false
      end

      def use_runner?
        false
      end
    end
  end
end
