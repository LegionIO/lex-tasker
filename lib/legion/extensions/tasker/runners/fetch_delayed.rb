module Legion::Extensions::Tasker::Runners
  module FetchDelayed
    include Legion::Extensions::Helpers::Lex

    def fetch(**_opts)
      tasks = Legion::Data::Model::Task.where(status: 'task.delayed')
      tasks_pushed = []
      log.debug "tasks.count = #{tasks.count}"
      tasks.each do |task|
        relationship = task.relationship
        next if !task.relationship.nil? && Time.now < task.values[:created] + relationship.values[:delay]

        # next if Time.now < task.values[:created] + task.values[:delay]

        subtask = Legion::Transport::Messages::SubTask.new(
          relationship_id:     relationship.values[:id],
          chain_id:            relationship.values[:chain_id],
          trigger_runner_id:   relationship.trigger.runner.values[:id],
          trigger_function_id: relationship.values[:trigger_id],
          function_id:         relationship.action.values[:id],
          function:            relationship.action.values[:name],
          runner_id:           relationship.action.values[:runner_id],
          runner_class:        relationship.action.runner.values[:namespace],
          conditions:          relationship.values[:conditions],
          transformation:      relationship.values[:transformation],
          # debug:                relationship.values[:debug],
          task_id:             task.values[:id]
          # results:              task.values[:payload]
        )
        subtask.publish
        task.update(status: 'conditioner.queued')
        tasks_pushed.push(task.values[:id])
      rescue StandardError => e
        task.update(status: 'task.push_exception')
        log.error e.message
        log.error e.backtrace
      end

      { success: true, count: tasks_pushed.count, tasks: tasks_pushed }
    rescue StandardError => e
      Legion::Logging.error e.message
      Legion::Logging.error e.backtrace
    end

    def push(**_opts)
      Legion::Extensions::Tasker::Transport::Messages::FetchDelayed.new.publish
      { success: true }
    end
  end
end
