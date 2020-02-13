require 'legion/transport/messages/subtask'

module Legion::Extensions::Tasker
  module Runners
    class CheckSubtask
      def self.check_subtasks(runner_namespace:, **payload)
        unless payload.key? :namespace_id
          namespace_record = Legion::Data::Model::Namespace.where(namespace: runner_namespace.downcase).first
        end
        namespace_record = Legion::Data::Model::Namespace[payload[:namespace_id]] if payload.key? :namespace_id
        Legion::Logging.warn "namespace is nil in check_subtasks #{payload}" if namespace_record.nil?
        return { success: false } if namespace_record.nil?

        function = Legion::Data::Model::Function
                   .where(namespace_id: namespace_record.values[:id])
                   .where(name: payload[:function])
                   .first

        Legion::Logging.warn namespace_record.values[:id] if function.nil?
        Legion::Logging.warn "function is nil in check_subtasks #{payload}" if function.nil?
        return { success: false } if function.nil?

        relationships = Legion::Data::Model::Relationship
                        .where(trigger_id: function.values[:id])
                        .where(:active)

        return { success: true, count: relationships.count } if relationships.count.zero?

        relationships.each do |relationship|
          if relationship.values[:allow_new_chains].zero?
            next if relationship.chain.nil?
            next unless payload.key? :chain_id
            next unless relationship.values[:chain_id] == payload[:chain_id]
          end

          status =  relationship.values[:delay].zero? ? 'conditioner.queued' : 'task.delayed'
          task_id = create_task(relationship_id: relationship.values[:id], status: status, **payload)
          payload[:result] = {} if payload[:result].nil?

          subtask = Legion::Transport::Messages::SubTask.new(
            relationship_id:      relationship.values[:id],
            chain_id:             relationship.values[:chain_id],
            trigger_namespace_id: namespace_record.values[:id],
            trigger_function_id:  function.values[:id],
            function_id:          relationship.action.values[:id],
            function:             relationship.action.values[:name],
            namespace_id:         relationship.action.values[:namespace_id],
            namespace:            relationship.action.values[:namespace],
            conditions:           relationship.values[:conditions],
            transformation:       relationship.values[:transformation],
            task_id:              task_id,
            success:              payload[:result][:success] || true,
            results:              payload[:result]
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
