module Legion
  module Extensions
    module Tasker
      module Runners
        class Subtask
          def self.check_subtasks(payload)
            namespace = Legion::Data::Model::Namespace.where(namespace: payload[:namespace]).first
            function = Legion::Data::Model::Function.where(namespace_id: namespace.values[:id], name: payload[:method]).first
            relationships = Legion::Data::Model::Relationship.where(trigger_id: function.values[:id], active: true)
            relationships.each do |relationship|
              # Legion::Logging.warn relationship.values
            end
            # Legion::Logging.error 'TaskSubtask'
            # Legion::Logging.error payload
          end
        end
      end
    end
  end
end
