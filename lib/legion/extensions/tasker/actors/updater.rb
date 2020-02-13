module Legion::Extensions::Tasker
  module Actor
    class Updater < Legion::Extensions::Actors::Subscription
      def runner_function
        'update_status'
      end
    end
  end
end
