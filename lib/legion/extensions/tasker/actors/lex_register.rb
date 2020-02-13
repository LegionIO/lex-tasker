module Legion::Extensions::Tasker
  module Actor
    class LexRegister < Legion::Extensions::Actors::Subscription
      def runner_function
        'save'
      end

      def use_runner
        false
      end
    end
  end
end
