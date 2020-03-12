module Legion::Extensions::Tasker
  module Actor
    class CheckSubtask < Legion::Extensions::Actors::Subscription
      def runner_function
        'check_subtasks'
      end

      def check_subtask?
        false
      end

      def use_runner?
        false
      end

      def generate_task?
        false
      end
    end
  end
end
