module Legion::Extensions::Tasker::Runners
  class FetchDelayed
    def self.fetch(**opts)
      tasks = Legion::Data::Model::Task.where(status: 'task.delayed')
      tasks.each do |task|
        relationship = task.relationship

        subtask = Legion::Transport::Messages::SubTask.new(
          relationship_id:      relationship.values[:id],
          chain_id:             relationship.values[:chain_id],
          trigger_namespace_id: relationship.trigger.namespace.values[:id],
          trigger_function_id:  relationship.values[:trigger_id],
          function_id:          relationship.action.values[:id],
          function:             relationship.action.values[:name],
          namespace_id:         relationship.action.values[:namespace_id],
          conditions:           relationship.values[:conditions],
          transformation:       relationship.values[:transformation],
          task_id:              task.values[:id],
          results:              task.values[:payload]
        )
        subtask.publish
        task.update(status: 'conditioner.queued')
      end
    rescue StandardError => e
      Legion::Logging.runner_exception(e, opts)
    end

    def self.push(**opts)
      Legion::Extensions::Tasker::Transport::Messages::FetchDelayed.new.publish
    rescue StandardError => e
      Legion::Logging.runner_exception(e, opts)
    end
  end
end
