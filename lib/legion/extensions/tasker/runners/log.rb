module Legion::Extensions::Tasker
  module Runners
    module Log
      def self.add_log(task_id:, entry:, function: nil, runner_class: nil, **opts)
        entry = JSON.dump(entry) unless entry.is_a? String
        insert = { task_id: task_id, entry: entry }
        if opts.key?(:node_id)
          insert[:node_id] = payload[:node_id]
        elsif opts.key?(:name)
          node = Legion::Data::Model::Node.where(opts[:name]).first
          insert[:node_id] = node.values[:id] unless node.nil?
        end
        insert[:function_id] = opts[:function_id] if opts.key? :function_id

        unless function.nil? && runner_class.nil?
          runner = Legion::Data::Model::Runner.where(namespace: runner_class).first
          insert[:function_id] = runner.functions_dataset.where(name: function).first.values[:id] unless runner.values.nil?
        end

        id = Legion::Data::Model::TaskLog.insert(insert)

        result = { success: !id.nil?, id: id }
        result
      end

      def self.delete_log(id:, **_opts)
        delete = Legion::Data::Model::TaskLog[id].delete
        { success: delete.positive?, count: delete, deleted_id: id }
      end

      def self.delete_task_logs(task_id:, **_opts)
        delete = Legion::Data::Model::TaskLog.where(task_id: task_id).delete
        { success: delete.positive?, count: delete, deleted_task_id: task_id }
      end

      def self.delete_node_logs(node_id:, **_opts)
        delete = Legion::Data::Model::TaskLog.where(node_id: node_id).delete
        { success: delete.positive?, count: delete, deleted_node_id: node_id }
      end

      def self.delete_all(**_opts)
        delete = Legion::Data::Model::TaskLog.all.delete
        { success: delete.positive?, count: delete }
      end
    end
  end
end
