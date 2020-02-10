module Legion::Extensions::Tasker
  module Runners
    class LexRegister
      def self.save(payload)
        namespace = create_namespace(payload)
        namespace_id = namespace[:namespace_id]

        function = Legion::Data::Model::Function.where(namespace_id: namespace_id, name: payload[:function]).first
        if function.nil?
          function = create_function(function: payload[:function], namespace_id: namespace_id)
        else
          update_function(function_id: function.values[:id], namespace_id: namespace_id, **payload)
        end

        result = { success: true }
        result[:namespace_id] = namespace_id
        result[:namespace] = namespace
        result[:function_id] = function.values[:id]
        result[:function] = payload[:function]

        result = { success: true }
        result
      end

      def self.update_namespace(payload)
        namespace = Legion::Data::Model::Namespace
        namespace = namespace.where(namespace: payload[:namespace]) unless payload[:namespace].nil?
        namespace = namespace.where(id: payload[:namespace_id]) unless payload[:namespace_id].nil?
        namespace = namespace.first

        update = {}
        namespace_array = payload[:namespace].split('::')
        update[:queue] = if payload[:namespace_queue].nil?
                           "#{namespace_array[2]}.#{namespace_array[4]}"
                         else
                           payload[:namespace_queue]
                         end

        update[:uri] = payload[:namespace_uri].nil? ? "#{namespace_array[2]}/#{namespace_array[4]}" : payload[:namespace_uri]
        update[:active] = payload[:active] unless payload[:active].nil?

        update[:exchange] = payload[:exchange].nil? ? namespace_array[2] : payload[:exchange]
        update[:routing_key] = payload[:routing_key].nil? ? namespace_array[4] : payload[:routing_key]
        results = namespace.update(update)
        { success: true, namespace_id: namespace.values[:id], values: results }
      rescue StandardError => e
        Legion::Logging.error e.message
        Legion::Logging.error e.backtrace
        { success: false, error: e.message, backtrace: e.backtrace }
      end

      def self.create_namespace(payload)
        require 'legion/data/models/namespace'
        insert = { namespace: payload[:namespace] }
        insert[:queue] = payload[:queue] unless payload[:queue].nil?
        insert[:uri] = payload[:uri] unless payload[:uri].nil?

        namespace = Legion::Data::Model::Namespace[namespace: payload[:namespace]]
        return update_namespace(payload) unless namespace.nil?

        namespace_id = Legion::Data::Model::Namespace.insert(insert)
        results = Legion::Data::Model::Namespace[namespace_id]
        { success: true, namespace_id: namespace_id, values: results }
      end

      def self.create_function(namespace_id:, function:, **_opts)
        function_id = Legion::Data::Model::Function.insert(namespace_id: namespace_id, name: function)
        Legion::Data::Model::Function[function_id]
      end

      def self.update_function(function_id:, **opts)
        params = {}
        opts[:params].each { |param| params[param[1]] = param[0] }

        update = Legion::Data::Model::Function[function_id].update(args: Legion::JSON.dump(params))
        { success: true, function_id: function_id, values: update.values }
      rescue StandardError => e
        { success: false, error: e.message.to_s, backtrace: e.backtrace }
      end

      def self.delete_function(function_id:, **opts); end
    end
  end
end
