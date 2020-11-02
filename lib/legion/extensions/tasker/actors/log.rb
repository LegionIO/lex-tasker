module Legion::Extensions::Tasker
  module Actor
    class Log < Legion::Extensions::Actors::Subscription
      def check_subtask?
        false
      end

      def generate_task?
        false
      end
    end
  end
end
