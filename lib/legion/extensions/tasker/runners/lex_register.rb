module Legion
  module Extensions
    module Tasker
      module Runners
        class LexRegister
          def self.save(payload)
            require 'legion/data/models/namespace'
            require 'legion/data/models/function'

            # namespace = Legion::Data::Model::Namespace.where(namespace: payload[:namespace]).first
            namespace = create_namespace(payload)
            namespace_id = namespace.values[:id]

            function = Legion::Data::Model::Function.where(namespace_id: namespace_id, name: payload[:method]).first
            function = create_function(method: payload[:method], namespace_id: namespace_id) if function.nil?

            result = { success: true }
            result[:namespace_id] = namespace_id
            result[:namespace] = namespace
            result[:function_id] = function.values[:id]
            result[:function] = payload[:method]

            result = { success: true }
            result
          end

          def self.update_namespace(payload)
            require 'legion/data/models/namespace'
            namespace = Legion::Data::Model::Namespace
            namespace = namespace.where(namespace: payload[:namespace]) unless payload[:namespace].nil?
            namespace = namespace.where(id: payload[:namespace_id]) unless payload[:namespace_id].nil?
            namespace = namespace.first

            update = {}
            update[:queue] = payload[:namespace_queue] unless payload[:namespace_queue].nil?
            update[:uri] = payload[:namespace_uri] unless payload[:namespace_uri].nil?
            update[:active] = payload[:active] unless payload[:active].nil?
            namespace.update(update)
            namespace
          end

          def self.create_namespace(payload)
            require 'legion/data/models/namespace'
            insert = { namespace: payload[:namespace] }
            insert[:queue] = payload[:queue] unless payload[:queue].nil?
            insert[:uri] = payload[:uri] unless payload[:uri].nil?

            namespace = Legion::Data::Model::Namespace[namespace: payload[:namespace]]
            return update_namespace(payload) unless namespace.nil?

            namespace_id = Legion::Data::Model::Namespace.insert(insert)
            Legion::Data::Model::Namespace[namespace_id]
          end

          def self.create_function(payload)
            require 'legion/data/models/function'
            insert = { namespace_id: payload[:namespace_id], name: payload[:method] }
            function_id = Legion::Data::Model::Function.insert(insert)
            Legion::Data::Model::Function[function_id]
          end
        end
      end
    end
  end
end
