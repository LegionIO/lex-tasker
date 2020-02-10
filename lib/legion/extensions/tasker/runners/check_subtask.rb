require 'legion/transport/messages/subtask'

module Legion
  module Extensions
    module Tasker
      module Runners
        class CheckSubtask
          def self.check_subtasks(namespace:, **payload)
            namespace = Legion::Data::Model::Namespace.where(namespace: namespace.downcase).first
            function = Legion::Data::Model::Function.where(namespace_id: namespace.values[:id], name: payload[:method]).first
            relationships = Legion::Data::Model::Relationship.where(trigger_id: function.values[:id], active: true)
            return { success: true, count: relationships.count } if relationships.count.zero?

            relationships.each do |relationship|
              status =  relationship.values[:delay].zero? ? 'conditioner.queued' : 'task.delayed'
              task_id = create_task(relationship_id: relationship.values[:id], status: status, **payload)
              payload[:result] = {} if payload[:result].nil?
              success = payload[:result][:success].nil? ? 'unknown' : payload[:result][:success]
              results = payload[:result][:results].nil? ? {} : payload[:result][:results]

              subtask = Legion::Transport::Messages::SubTask.new(
                relationship_id:      relationship.values[:id],
                chain_id:             relationship.values[:chain_id],
                trigger_namespace_id: namespace.values[:id],
                trigger_function_id:  function.values[:id],
                function_id:          relationship.action.values[:id],
                function:             relationship.action.values[:name],
                namespace_id:         relationship.action.values[:namespace_id],
                conditions:           relationship.values[:conditions],
                transformation:       relationship.values[:transformation],
                task_id:              task_id,
                success:              success,
                results:              results
              )
              subtask.publish if relationship.values[:delay].zero?
            end
            { success: true, count: relationships.count }
          end

          def self.create_task(relationship_id:, status: 'conditioner.queued', **options)
            insert = { relationship_id: relationship_id, status: status }

            unless options[:task_id].nil?
              insert[:parent_id] = options[:task_id]
              master = Legion::Data::Model::Task[options[:task_id]]
              insert[:master_id] = master.values[:master_id] unless master.values[:master_id].nil?
              insert[:master_id] = options[:task_id] if master.values[:master_id].nil?
            end
            insert[:payload] = Legion::JSON.dump(options) unless options.nil? || options.empty?
            Legion::Data::Model::Task.insert(insert)
          end
        end
      end
    end
  end
end
