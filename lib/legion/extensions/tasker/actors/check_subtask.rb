module Legion::Extensions::Tasker
  module Actor
    class CheckSubtask < Legion::Extensions::Actors::Subscription
      def runner_function
        'check_subtasks'
      end

      def subscribe(manual = true)
        @queue.subscribe(manual_ack: manual, block: false) do |delivery_info, _metadata, payload|
          message = Legion::JSON.load(payload)
          Legion::Extensions::Tasker::Runners::CheckSubtask.check_subtasks(namespace: message['namespace'], **message)
          @queue.acknowledge(delivery_info.delivery_tag) if manual
        rescue StandardError => e
          Legion::Logging.error(e.message)
          Legion::Logging.error(e.backtrace)
          @queue.reject(delivery_info.delivery_tag) if manual
        end
      end
    end
  end
end
