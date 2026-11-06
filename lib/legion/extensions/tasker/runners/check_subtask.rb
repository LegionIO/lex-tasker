# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      module Runners
        module CheckSubtask
          extend self # -- Runner module methods need the included helpers.

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def check_subtasks(runner_class:, function:, **opts)
            trigger = tasker_find_trigger(runner_class: runner_class, function: function)
            return { success: true, subtasks: 0, created: 0 } unless trigger

            parent = Legion::Data::Model::Task[opts.fetch(:task_id)]
            raise ArgumentError, 'subtask parent does not exist' unless parent

            blocked = tasker_blocked_status(task: parent.values)
            blocked ||= tasker_blocked_status(task: opts)
            return { success: true, subtasks: 0, created: 0, status: blocked } if blocked

            relationships = tasker_find_subtasks(trigger_id: trigger[:function_id]).select do |relationship|
              relationship[:allow_new_chains] || (relationship[:chain_id] && relationship[:chain_id] == opts[:chain_id])
            end
            results = opts.fetch(:results) { opts.fetch(:result, opts.fetch(:args, {})) }
            results = [results] unless results.is_a?(Array)
            depth = tasker_child_depth(parent: parent.values, context: opts, count: relationships.length * results.length)

            children = relationships.flat_map do |relationship|
              results.map do |result|
                tasker_create_child(relationship: relationship, parent: parent.values, trigger: trigger,
                                    result: result, depth: depth, context: opts)
              end
            end
            { success: true, subtasks: children.length, created: children.length, task_ids: children.map { |child| child[:id] } }
          end

          private

          def tasker_child_depth(parent:, context:, count:)
            policy = settings.fetch(:execution)
            depth = [Integer(parent[:depth]), Integer(context.fetch(:depth, parent[:depth]))].max + 1
            raise ArgumentError, 'task chain depth exceeds configured maximum' if depth > policy.fetch(:max_depth)
            raise ArgumentError, 'task fanout exceeds configured maximum' if count > policy.fetch(:max_fanout)

            depth
          end

          def tasker_create_child(relationship:, parent:, trigger:, result:, depth:, context:)
            delay = tasker_delay_seconds(delay: relationship[:delay])
            metadata = context.slice(*Legion::Transport::Task::Protocol::METADATA_FIELDS).except(:task_id, :message_id)
            envelope = metadata.merge(relationship.slice(:relationship_id, :chain_id, :function_id, :function, :runner_class,
                                                         :runner_routing_key, :debug, :conditions, :transformation, :engine, :schema, :engine_options).compact)
            envelope.merge!(args: result.is_a?(Hash) ? result : context.fetch(:args, {}), results: result,
                            function_args: context.fetch(:function_args, context.fetch(:args, {})),
                            parent_id: parent[:id], master_id: parent[:master_id] || parent[:id], depth: depth,
                            trigger_runner_id: trigger[:runner_id], trigger_function_id: trigger[:function_id])
            stage = tasker_stage(envelope: envelope)
            envelope[:routing_key] = stage[:routing_key]
            dispatch = { message_type: stage[:message_type], options: envelope }
            values = {
              relationship_id: relationship[:relationship_id], function_id: relationship[:function_id],
              parent_id: parent[:id], master_id: envelope[:master_id], depth: depth,
              status: delay.positive? ? task_status(name: :delayed) : stage[:status],
              task_delay: delay.ceil, payload: json_dump(dispatch), function_args: json_dump(envelope[:args])
            }
            task = Legion::Data::Model::Task.create(values)
            tasker_publish(message_type: dispatch[:message_type], options: envelope.merge(task_id: task.id)) unless delay.positive?
            task.values
          end
        end
      end
    end
  end
end
