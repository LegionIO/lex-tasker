# frozen_string_literal: true

require 'legion/json/helper'
require 'legion/data'
require 'legion/logging/helper'

module Legion
  module Extensions
    module Tasker
      module Runners
        module Log
          extend self

          include Legion::JSON::Helper
          include Legion::Logging::Helper

          def add_log(task_id:, entry:, function: nil, runner_class: nil, **opts)
            entry = json_dump(entry) unless entry.is_a? String
            insert = { task_id: task_id, entry: entry }
            if opts.key?(:node_id)
              insert[:node_id] = opts[:node_id]
            elsif opts.key?(:name)
              node = Legion::Data::Model::Node.where(name: opts[:name]).first
              insert[:node_id] = node.values[:id] unless node.nil?
            end
            insert[:function_id] = opts[:function_id] if opts.key? :function_id

            unless function.nil? && runner_class.nil?
              runner = Legion::Data::Model::Runner.first(namespace: runner_class)
              target = runner&.functions_dataset&.first(name: function)
              raise ArgumentError, 'task log function does not exist' unless target

              insert[:function_id] = target[:id]
            end

            id = Legion::Data::Model::TaskLog.create(insert).id

            { success: !id.nil?, id: id }
          end

          def delete_log(id:, **)
            delete = Legion::Data::Model::TaskLog.where(id: id).delete
            { success: delete.positive?, count: delete, deleted_id: id }
          end

          def delete_task_logs(task_id:, **)
            delete = Legion::Data::Model::TaskLog.where(task_id: task_id).delete
            { success: delete.positive?, count: delete, deleted_task_id: task_id }
          end

          def delete_node_logs(node_id:, **)
            delete = Legion::Data::Model::TaskLog.where(node_id: node_id).delete
            { success: delete.positive?, count: delete, deleted_node_id: node_id }
          end

          def delete_all(**)
            delete = Legion::Data::Model::TaskLog.dataset.delete
            { success: delete.positive?, count: delete }
          end
        end
      end
    end
  end
end
