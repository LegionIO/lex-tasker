require 'legion/transport/messages/task_subtask'
require 'legion/data/models/relationship'
require 'legion/data/models/namespace'
require 'legion/data/models/task'

module Legion
  module Extensions
    module Tasker
      module Runners
        class TaskCheckSubtask
          def self.check_subtasks(payload)
            namespace = Legion::Data::Model::Namespace.where(namespace: payload[:namespace]).first
            function = Legion::Data::Model::Function.where(namespace_id: namespace.values[:id], name: payload[:method]).first
            relationships = Legion::Data::Model::Relationship.where(trigger_id: function.values[:id], active: true)
            return { success: true, count: relationships.count } if relationships.count.zero?

            relationships.each do |relationship|
              task_id = create_task(relationship.values[:id], payload)
              runner = { relationship_id: relationship.values[:id] }
              runner[:method] = relationship.action.values[:name]
              runner[:namespace] = relationship.action.namespace.values[:namespace]
              runner[:args] = {}
              hash = { runner: runner }
              hash[:result] = payload[:result] unless payload[:result].nil?

              message = Legion::Transport::Messages::TaskSubTask.new(
                relationship.values[:id],
                function.values[:id],
                relationship.values[:conditions],
                relationship.values[:transformation],
                task_id,
                payload
              )
              message.publish
            end
            { success: true, count: relationships.count }
          end

          def self.create_task(relationship_id, options = {})
            insert = {}
            insert[:status] = 'conditioner.queued' if options[:status].nil?
            insert[:status] = options[:status] unless options[:status].nil?
            insert[:relationship_id] = relationship_id
            # Legion::Logging.fatal options
            # Legion::Logging.fatal options[:result][:task_id] unless options[:result][:task_id].nil?

            unless options[:task_id].nil?
              insert[:parent_id] = options[:task_id]
              master = Legion::Data::Model::Task[options[:task_id]]
              insert[:master_id] = master.values[:master_id] unless master.values[:master_id].nil?
              insert[:master_id] = options[:task_id] if master.values[:master_id].nil?
            end
            insert[:payload] = options[:payload] unless options[:payload].nil?
            Legion::Data::Model::Task.insert(insert)
          end
        end
      end
    end
  end
end
