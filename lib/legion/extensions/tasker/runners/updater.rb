module Legion::Extensions::Tasker
  module Runners
    module Updater
      include Legion::Extensions::Helpers::Lex

      def update_status(task_id:, **opts)
        task = Legion::Data::Model::Task[task_id]
        update_hash = {}
        %i[status function_args payload results].each do |column|
          next unless opts.key? column

          update_hash[column] = if opts[column].is_a? String
                                  opts[column]
                                else
                                  to_json opts[column]
                                end
        end
        { success: true, changed: false, task_id: task_id } if update_hash.count.zero?
        task.update(update_hash)

        { success: true, changed: true, task_id: task_id, updates: update_hash }
      end
    end
  end
end
