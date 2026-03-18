# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Runners
        module FetchDelayed
          include Legion::Extensions::Tasker::Helpers::TaskFinder
          include Legion::Extensions::Helpers::Task

          def fetch(**_opts)
            find_delayed.each do |task|
              next if delayed_by?(task[:relationship_delay], task[:created])
              next if delayed_by?(task[:task_delay], task[:created])

              subtask_hash = build_delayed_hash(task)
              send_task(**subtask_hash)
              update_delayed_status(task[:id], subtask_hash[:routing_key])
            end
          end

          def delayed_by?(delay, created)
            delay.is_a?(Integer) && delay.positive? && Time.now < created + delay
          end

          def build_delayed_hash(task)
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
            subtask_hash[:routing_key] = delayed_routing_key(task)
            subtask_hash
          end

          def delayed_routing_key(task)
            if task[:conditions].is_a?(String) && task[:conditions].length > 4
              'task.subtask.conditioner'
            elsif task[:transformation].is_a?(String) && task[:transformation].length > 4
              'task.subtask.transformation'
            else
              task[:runner_routing_key]
            end
          end

          def update_delayed_status(task_id, routing_key)
            status = case routing_key
                     when 'task.subtask.conditioner' then 'conditioner.queued'
                     when 'task.subtask.transformation' then 'transformer.queued'
                     else 'task.queued'
                     end
            task_update(task_id, status)
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
    end
  end
end
