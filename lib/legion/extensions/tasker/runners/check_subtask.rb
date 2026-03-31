# frozen_string_literal: true

require 'legion/transport/messages/subtask'

module Legion
  module Extensions
    module Tasker
      module Runners
        module CheckSubtask
          include Legion::Extensions::Helpers::Lex
          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def check_subtasks(runner_class:, function:, **opts)
            trigger = find_trigger(runner_class: runner_class, function: function)
            return { success: true, subtasks: 0 } unless trigger.is_a?(Hash)

            find_subtasks(trigger_id: trigger[:function_id]).each do |relationship|
              next unless chain_matches?(relationship, opts)

              task_hash = build_task_hash(relationship, opts)
              dispatch_task(task_hash, trigger, opts)
            end
          end

          def chain_matches?(relationship, opts)
            return true if relationship[:allow_new_chains]

            !relationship[:chain_id].nil? && opts.key?(:chain_id) && relationship[:chain_id] == opts[:chain_id]
          end

          def build_task_hash(relationship, opts)
            task_hash = relationship.dup
            task_hash[:status] = relationship[:delay].to_i.zero? ? 'conditioner.queued' : 'task.delayed'
            task_hash[:payload] = opts
            task_hash[:master_id] = resolve_master_id(opts)
            task_hash[:parent_id] = opts[:task_id] if opts.key?(:task_id)
            task_hash[:routing_key] = subtask_routing_key(relationship)
            task_hash
          end

          def resolve_master_id(opts)
            return opts[:master_id] if opts.key?(:master_id)
            return opts[:parent_id] if opts.key?(:parent_id)

            opts[:task_id] if opts.key?(:task_id)
          end

          def subtask_routing_key(relationship)
            if relationship[:conditions].is_a?(String) && relationship[:conditions].length > 4
              'task.subtask.conditioner'
            elsif relationship[:transformation].is_a?(String) && relationship[:transformation].length > 4
              'task.subtask.transformation'
            else
              relationship[:runner_routing_key]
            end
          end

          def dispatch_task(task_hash, trigger, opts)
            trigger_info = { trigger_runner_id: trigger[:runner_id], trigger_function_id: trigger[:function_id] }
            results_value = opts[:result] || opts[:results]

            if results_value.is_a?(Array)
              results_value.each do |result|
                send_task(results: result, **trigger_info, **task_hash)
              end
            else
              send_task(results: resolve_results(opts), **trigger_info, **task_hash)
            end
          end

          def resolve_results(opts)
            return opts[:results] if opts[:results].is_a?(Hash)
            return opts[:result] if opts[:result].is_a?(Hash)

            opts
          end

          def send_task(**opts)
            opts[:results] = opts[:result] if opts.key?(:result) && !opts.key?(:results)
            opts[:success] = if opts.key?(:result) && opts.key?(:success)
                               opts[:result].is_a?(Hash) ? opts[:result][:success] : opts[:success]
                             elsif opts.key?(:success)
                               opts[:success]
                             else
                               1
                             end

            opts[:task_id] = insert_task(**opts)
            return { status: true } unless opts[:delay].zero?

            Legion::Transport::Messages::SubTask.new(**opts).publish
          end

          def insert_task(relationship_id:, function_id:, **opts)
            return nil unless defined?(Legion::Data::Model::Task)

            status = opts.fetch(:status, 'task.queued')
            master_id = opts[:master_id]
            parent_id = opts[:parent_id]

            insert_hash = { relationship_id: relationship_id, function_id: function_id, status: status }
            insert_hash[:master_id] = master_id.is_a?(Integer) ? master_id : (parent_id if parent_id.is_a?(Integer))
            insert_hash[:parent_id] = parent_id if parent_id.is_a?(Integer)
            insert_hash[:payload] = json_dump(opts)
            Legion::Data::Model::Task.insert(insert_hash)
          end
        end
      end
    end
  end
end
