require 'legion/transport/messages/subtask'

module Legion::Extensions::Tasker
  module Runners
    module CheckSubtask
      include Legion::Extensions::Helpers::Lex

      def check_subtasks(runner_class:, function:, **opts)
        runner_record = Legion::Data::Model::Runner[namespace: runner_class]
        return if runner_record.nil?

        function_record = runner_record.functions_dataset[name: function]
        return if function_record.nil?

        relationships = function_record.trigger_relationships_dataset.where(:active)
        relationships.where(chain_id: opts[:chain_id] || :allow_new_chains) if opts.key? :chain_id
        return { success: true, count: relationships.count } if relationships.count.zero?

        relationships.each do |relationship|
          unless relationship.values[:allow_new_chains]
            next if relationship.chain.nil?
            next unless opts.key? :chain_id
            next unless relationship.values[:chain_id] == opts[:chain_id]
          end

          action_function = relationship.action
          action_runner = action_function.runner

          status = relationship.values[:delay].zero? ? 'conditioner.queued' : 'task.delayed'

          task_id_hash = { runner_class:    action_runner.values[:namespace],
                           function:        action_function.values[:name],
                           status:          status,
                           relationship_id: relationship.values[:id] }
          task_id_hash[:payload] = opts

          if opts.key? :master_id
            task_id_hash[:master_id] = opts[:master_id]
          elsif opts.key? :parent_id
            task_id_hash[:master_id] = opts[:parent_id]
          elsif opts.key? :task_id
            task_id_hash[:master_id] = opts[:task_id]
          end

          task_id_hash[:parent_id] = opts[:task_id] if opts.key? :task_id
          if opts[:result].is_a? Array
            opts[:result].each do |result|
              send_task(task_id_hash,
                        relationship:    relationship,
                        runner_record:   runner_record,
                        function_record: function_record,
                        action_function: action_function,
                        action_runner:   action_runner,
                        result:          result)
            end
          else
            send_task(task_id_hash,
                      relationship:    relationship,
                      runner_record:   runner_record,
                      function_record: function_record,
                      action_function: action_function,
                      action_runner:   action_runner,
                      **opts)
          end
        end
      rescue StandardError => e
        Legion::Logging.fatal e.message
        Legion::Logging.fatal e.backtrace
        Legion::Logging.fatal runner_class
        Legion::Logging.fatal function
        Legion::Logging.fatal opts.keys
        Legion::Logging.fatal opts[:entry]
      end

      def send_task(task_id_hash, relationship:, runner_record:, function_record:, action_function:, action_runner:, **opts) # rubocop:disable Layout/LineLength
        task_id = Legion::Runner::Status.generate_task_id(**task_id_hash)[:task_id]

        return { status: true } unless relationship.values[:delay].zero?

        subtask_hash = {
          relationship_id:     relationship.values[:id],
          chain_id:            relationship.values[:chain_id],
          trigger_runner_id:   runner_record.values[:id],
          trigger_function_id: function_record.values[:id],
          function_id:         action_function.values[:id],
          function:            action_function.values[:name],
          runner_id:           action_runner.values[:id],
          runner_class:        action_runner.values[:namespace],
          conditions:          relationship.values[:conditions],
          transformation:      relationship.values[:transformation],
          debug:               relationship.values[:debug] && 1 || 0,
          task_id:             task_id,
          results:             opts[:result]
        }

        subtask_hash[:routing_key] = if subtask_hash[:conditions].is_a?(String) && subtask_hash[:conditioners].length > 4 # rubocop:disable Layout/LineLength
                                       'task.subtask.conditioner'
                                     elsif subtask_hash[:transformation].is_a?(String) && subtask_hash[:transformation].length > 4 # rubocop:disable Layout/LineLength
                                       'task.subtask.transform'
                                     else
                                       "#{runner_record.extension.values[:exchange]}.#{runner_record.values[:queue]}.#{subtask_hash[:function]}" # rubocop:disable Layout/LineLength
                                     end

        subtask_hash[:success] = if opts.nil?
                                   1
                                 elsif opts.key?(:result)
                                   # opts[:result][:success]
                                   1
                                 elsif opts.key?(:success)
                                   opts[:success]
                                 else
                                   1
                                 end
        Legion::Transport::Messages::SubTask.new(**subtask_hash).publish
      end
    end
  end
end
