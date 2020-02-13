module Legion::Extensions::Tasker::Runners
  class FetchDelayed
    def self.fetch(**_opts)
      tasks = Legion::Data::Model::Task.where(status: 'task.delayed')
      tasks_pushed = []
      tasks.each do |task|
        relationship = task.relationship
        next if Time.now < task.values[:created_at] + relationship.values[:delay]

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
        tasks_pushed.push(task.values[:id])
      end

      { success: true, count: tasks_pushed.count, tasks: tasks_pushed }
    end

    def self.push(**_opts)
      Legion::Extensions::Tasker::Transport::Messages::FetchDelayed.new.publish
      { success: true }
    end
  end
end
