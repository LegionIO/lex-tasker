require 'legion/transport/messages/subtask'

module Legion::Extensions::Tasker
  module Runners
    module CheckSubtask
      include Legion::Extensions::Helpers::Lex
      extend Legion::Extensions::Tasker::Helpers::FindSubtask

      def check_subtasks(runner_class:, function:, **opts)
        trigger = find_trigger(runner_class: runner_class, function: function)

        find_subtasks(trigger_id: trigger[:function_id]).each do |relationship|
          unless relationship[:allow_new_chains]
            next if relationship[:chain_id].nil?
            next unless opts.key? :chain_id
            next unless relationship[:chain_id] == opts[:chain_id]
          end

          task_hash = relationship
          task_hash[:status] = relationship[:delay].zero? ? 'conditioner.queued' : 'task.delayed'
          task_hash[:payload] = opts

          if opts.key? :master_id
            task_hash[:master_id] = opts[:master_id]
          elsif opts.key? :parent_id
            task_hash[:master_id] = opts[:parent_id]
          elsif opts.key? :task_id
            task_hash[:master_id] = opts[:task_id]
          end

          task_hash[:parent_id] = opts[:task_id] if opts.key? :task_id
          task_hash[:routing_key] = if relationship[:conditions].is_a?(String) && relationship[:conditions].length > 4
                                      'task.subtask.conditioner'
                                    elsif relationship[:transformation].is_a?(String) && relationship[:transformation].length > 4 # rubocop:disable Layout/LineLength
                                      'task.subtask.transformation'
                                    else
                                      relationship[:runner_routing_key]
                                    end

          if opts[:result].is_a? Array
            opts[:result].each do |result|
              send_task(results:             result,
                        trigger_runner_id:   trigger[:runner_id],
                        trigger_function_id: trigger[:function_id],
                        **task_hash)
            end
          else
            results = if opts[:results].is_a? Hash
                        opts[:results]
                      elsif opts[:result].is_a? Hash
                        opts[:result]
                      else
                        opts
                      end
            send_task(
              results:             results,
              trigger_runner_id:   trigger[:runner_id],
              trigger_function_id: trigger[:function_id],
              **task_hash
            )
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

        # opts[:task_id] = Legion::Runner::Status.generate_task_id(**opts)[:task_id]
        opts[:task_id] = insert_task(**opts)
        return { status: true } unless opts[:delay].zero?

        Legion::Transport::Messages::SubTask.new(**opts).publish
      end

      def insert_task(relationship_id:, function_id:, status: 'task.queued', master_id: nil, parent_id: nil, **opts)
        insert_hash = { relationship_id: relationship_id, function_id: function_id, status: status }
        insert_hash[:master_id] = if master_id.is_a? Integer
                                    master_id
                                  elsif parent_id.is_a? Integer
                                    parent_id
                                  end
        insert_hash[:parent_id] = parent_id if parent_id.is_a? Integer
        insert_hash[:payload] = Legion::JSON.dump(opts)
        # insert_hash[:function_args] = nil
        # insert_hash[:results] = nil
        Legion::Data::Model::Task.insert(insert_hash)
      end
    end
  end
end
