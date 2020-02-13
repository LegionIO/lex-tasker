module Legion::Extensions::Tasker
  module Runners
    class LexRegister
      def self.save(extension:, extension_namespace:, runner_namespace:, function:, **opts)
        extension_record = Legion::Data::Model::Extension.where(name: extension).first
        if extension_record.nil?
          create_extension(name: extension, namespace: extension_namespace)
          extension_record = Legion::Data::Model::Extension.where(name: extension).first
        end

        namespace_record = Legion::Data::Model::Namespace
                           .where(namespace: runner_namespace)
                           .where(extension_id: extension_record.values[:id])
                           .first

        if namespace_record.nil?
          # Legion::Runner::Runner.new(self, 'create_namespace', {args:{extension_id: extension_record.values[:id], namespace: runner_namespace}})
          create_namespace(extension_id: extension_record.values[:id], namespace: runner_namespace)
          namespace_record = Legion::Data::Model::Namespace
                             .where(namespace: runner_namespace)
                             .where(extension_id: extension_record.values[:id])
                             .first
        else
          update_namespace(namespace_id: namespace_record.values[:id], **opts)
        end

        function_record = Legion::Data::Model::Function
                          .where(name: function)
                          .where(namespace_id: namespace_record.values[:id])
                          .first

        if function_record.nil?
          # Legion::Runner::Runner.new(self, 'create_function', {args:{namespace_id: namespace_record.values[:id], function: function, function_params: opts[:params]}})
          create_function(namespace_id: namespace_record.values[:id], function: function, function_params: opts[:params])
          function_record = Legion::Data::Model::Function
                            .where(name: function)
                            .where(namespace_id: namespace_record.values[:id])
                            .first
        end

        { success: true, function_id: function_record.values[:id], namespace_id: namespace_record.values[:id], extension_id: extension_record.values[:id] }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, extension: extension, extension_namespace: extension_namespace, runner_namespace: runner_namespace, function: function, **opts)
      end

      def self.create_extension(name:, namespace:, active: 1, **opts)
        insert_hash = { name: name, namespace: namespace, active: active }
        insert_hash[:user_owner] = opts[:user_owner] if opts.key? :user_owner
        insert_hash[:group_owner] = opts[:group_owner] if opts.key? :group_owner
        result = Legion::Data::Model::Extension.insert(insert_hash)
        { success: true, result: result, name: name, namespace: namespace }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, name: name, namespace: namespace, active: active, **opts)
      end

      def self.update_extension(extension_id:, **opts)
        extension = Legion::Data::Model::Extension[extension_id]
        update_hash = {}
        %w[name namespace user_owner group_owner].each do |column|
          update_hash[column.to_sym] = opts[column.to_sym] if opts.key? column.to_sym
        end
        result = extension.update(update_hash)
        { success: true, extension_id: extension_id, result: result, count: update_hash.count }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, extension_id: extension_id, **opts)
      end

      def self.delete_extension(extension_id:, **opts); end

      def self.update_namespace(namespace_id:, **opts)
        namespace = Legion::Data::Model::Namespace[namespace_id]
        extension = namespace.values[:namespace].split('::')[2].downcase
        runner = namespace.values[:namespace].split('::')[4].downcase
        update = {}
        if opts.key? :queue
          update[:queue] = opts[:queue]
        elsif namespace.values[:queue].nil? || namespace.values[:queue].empty?
          update[:queue] = "#{extension}.#{runner}"
        end

        if opts.key? :exchange
          update[:exchange] = opts[:exchange]
        elsif namespace.values[:exchange].nil? || namespace.values[:exchange].empty?
          update[:exchange] = extension
        end

        if opts.key? :routing_key
          update[:routing_key] = opts[:routing_key]
        elsif namespace.values[:routing_key].nil? || namespace.values[:routing_key].empty?
          update[:routing_key] = runner
        end

        if opts.key? :uri
          update[:uri] = opts[:uri]
        elsif namespace.values[:uri].nil?
          update[:uri] = "#{extension}/#{runner}"
        end

        { success: true, namespace_id: namespace_id, update: namespace.update(update) }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, namespace: namespace, **opts)
      end

      def self.create_namespace(namespace:, extension_id:, **opts)
        insert = { namespace: namespace, extension_id: extension_id }
        namespace = Legion::Data::Model::Namespace.insert(insert)
      rescue StandardError => e
        Legion::Logging.runner_exception(e, namespace: namespace, extension_id: extension_id, **opts)
      end

      def self.delete_namespace(namespace_id:, **opts)
        {
          success:     true,
          function_id: namespace_id,
          results:     Legion::Data::Model::Namespace[:namespace_id].delete
        }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, function_id: namespace_id, **opts)
      end

      def self.create_function(namespace_id:, function:, function_params: {}, **opts)
        function_hash = { namespace_id: namespace_id, name: function }
        params = {}
        function_params.each { |param| params[param[1]] = param[0] } if opts.key?(:params)
        function_hash[:params] = params unless params.count.zero?

        function_id = Legion::Data::Model::Function.insert(function_hash)
        { success: true, function_id: function_id, **opts }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, namespace_id: namespace_id, function: function, **opts)
      end

      def self.update_function(function_id:, **opts)
        function_update_hash = {}
        params = {}

        opts[:params].each { |param| params[param[1]] = param[0] } if opts.key? :params
        function_update_hash[:args] = params unless params.count.zero?

        update = Legion::Data::Model::Function[function_id].update(function_update_hash)
        { success: true, function_id: function_id, values: update.values }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, function_id: function_id, **opts)
      end

      def self.delete_function(function_id:, **opts)
        {
          success:     true,
          function_id: function_id,
          results:     Legion::Data::Model::Function[:function_id].delete
        }
      rescue StandardError => e
        Legion::Logging.runner_exception(e, function_id: function_id, **opts)
      end
    end
  end
end
