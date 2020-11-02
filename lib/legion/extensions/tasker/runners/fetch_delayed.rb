module Legion::Extensions::Tasker::Runners
  module FetchDelayed
    extend Legion::Extensions::Tasker::Helpers::FetchDelayed
    include Legion::Extensions::Helpers::Task

    def fetch(**_opts)
      find_delayed.each do |task|
        if task[:relationship_delay].is_a?(Integer) && task[:relationship_delay].positive?
          next if Time.now < task[:created] + task[:relationship_delay] # rubocop:disable Style/SoleNestedConditional
        end

        if task[:task_delay].is_a?(Integer) && task[:task_delay].positive?
          next if Time.now < task[:created] + task[:task_delay] # rubocop:disable Style/SoleNestedConditional
        end

        subtask_hash = {
          relationship_id: task[:relationship_id],
          chain_id:        task[:chain_id],
          function_id:     task[:function_id],
          function:        task[:function_name],
          runner_id:       task[:runner_id],
          runner_class:    task[:runner_class],
          task_id:         task[:id],
          exchange:        task[:exchange],
          queue:           task[:queue]
        }

        subtask_hash[:conditions] = task[:conditions] if task[:conditions].is_a?(String)
        subtask_hash[:transformation] = task[:transformation] if task[:transformation].is_a?(String)

        subtask_hash[:routing_key] = if task[:conditions].is_a?(String) && task[:conditions].length > 4
                                       'task.subtask.conditioner'
                                     elsif task[:transformation].is_a?(String) && task[:transformation].length > 4
                                       'task.subtask.transformation'
                                     else
                                       task[:runner_routing_key]
                                     end

        send_task(**subtask_hash)
        case subtask_hash[:routing_key]
        when 'task.subtask.conditioner'
          task_update(task[:id], 'conditioner.queued')
        when 'task.subtask.transformation'
          task_update(task[:id], 'transformer.queued')
        else
          task_update(task[:id], 'task.queued')
        end
      end
    end

    def send_task(**opts)
      opts[:results] = opts[:result] if opts.key?(:result) && !opts.key?(:results)
      opts[:success] = if opts.key?(:result) && opts.key?(:success)
                         opts[:result][:success]
                       elsif opts.key?(:success)
                         opts[:success]
                       else
                         1
                       end
      log.debug 'pushing delayed task to worker'
      Legion::Transport::Messages::Task.new(**opts).publish
    end

    def push(**_opts)
      Legion::Extensions::Tasker::Transport::Messages::FetchDelayed.new.publish
      { success: true }
    end

    include Legion::Extensions::Helpers::Lex
  end
end
