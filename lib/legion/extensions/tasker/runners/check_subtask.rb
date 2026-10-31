# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      module Runners
        module CheckSubtask
          extend self

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def check_subtasks(runner_class:, function:, **opts)
            trigger = find_trigger(runner_class: runner_class, function: function)
            return { success: true, subtasks: 0, created: 0 } unless trigger

            parent = Legion::Data::Model::Task[opts.fetch(:task_id)]
            raise ArgumentError, 'subtask parent does not exist' unless parent

            blocked = tasker_blocked_status(task: parent.values, now: Time.now)
            blocked ||= tasker_blocked_status(task: opts, now: Time.now)
            return { success: true, subtasks: 0, created: 0, status: blocked } if blocked

            relationships = find_subtasks(trigger_id: trigger[:function_id]).select do |relationship|
              relationship[:allow_new_chains] || (relationship[:chain_id] && relationship[:chain_id] == opts[:chain_id])
            end
            results = opts.fetch(:results) { opts.fetch(:result, opts.fetch(:args, {})) }
            results = [results] unless results.is_a?(Array)
            depth = tasker_child_depth(parent: parent.values, context: opts, count: relationships.length * results.length)

            children = relationships.flat_map do |relationship|
              results.each_with_index.map do |result, index|
                tasker_create_child(relationship: relationship, parent: parent.values, trigger: trigger,
                                    result: result, index: index, depth: depth, context: opts)
              end
            end
            { success: true, subtasks: children.length, created: children.count { |child| child[:created] },
              task_ids: children.map { |child| child[:task][:id] } }
          end

          private

          def tasker_child_depth(parent:, context:, count:)
            policy = task_execution_settings.fetch(:execution)
            depth = [Integer(parent[:depth]), Integer(context.fetch(:depth, parent[:depth]))].max + 1
            raise ArgumentError, 'task chain depth exceeds configured maximum' if depth > policy.fetch(:max_depth)
            raise ArgumentError, 'task fanout exceeds configured maximum' if count > policy.fetch(:max_fanout)

            depth
          end

          def tasker_create_child(relationship:, parent:, trigger:, result:, index:, depth:, context:)
            delay = tasker_delay_seconds(delay: relationship[:delay])
            metadata = context.slice(*task_execution_settings.fetch(:protocol).fetch(:metadata_fields).map(&:to_sym))
                              .except(:task_id, :attempt_id, :execution_token, :message_id)
            envelope = metadata.merge(relationship.slice(:relationship_id, :chain_id, :function_id, :function, :runner_class,
                                                         :runner_routing_key, :debug, :conditions, :transformation, :engine, :schema, :engine_options).compact)
            envelope.merge!(args: result.is_a?(Hash) ? result : context.fetch(:args, {}), results: result,
                            function_args: context.fetch(:function_args, context.fetch(:args, {})),
                            parent_id: parent[:id], master_id: parent[:master_id] || parent[:id], depth: depth,
                            trigger_runner_id: trigger[:runner_id], trigger_function_id: trigger[:function_id])
            deadlines = [parent[:deadline_at], context[:deadline_at]].compact.map { |value| value.is_a?(String) ? Time.parse(value) : value }
            envelope[:deadline_at] = deadlines.min unless deadlines.empty?
            stage = tasker_stage(envelope: envelope)
            envelope[:routing_key] = stage[:routing_key]
            key = "task:#{parent[:id]}:relationship:#{relationship[:relationship_id]}:child:#{index}"
            dispatch = { event_key: "#{key}:dispatch", message_type: stage[:message_type], options: envelope }
            values = {
              relationship_id: relationship[:relationship_id], function_id: relationship[:function_id],
              parent_id: parent[:id], master_id: envelope[:master_id], depth: depth,
              status: delay.positive? ? task_status(name: :delayed) : stage[:status],
              task_delay: delay.ceil, payload: dispatch, function_args: envelope[:args], deadline_at: envelope[:deadline_at]
            }
            Legion::Data::TaskExecution.create_task(values: values, idempotency_key: key, dispatch: delay.positive? ? nil : dispatch)
          end
        end
      end
    end
  end
end
