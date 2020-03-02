module Legion::Extensions::Tasker
  module Actor
    class CheckSubtask < Legion::Extensions::Actors::Subscription
      def runner_function
        'check_subtasks'
      end

      def use_runner
        false
      end

      def queue
        transport_class::Queues::CheckSubtask
      end
    end
  end
end
