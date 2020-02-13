module Legion::Extensions::Tasker
  module Runners
    class Updater
      def self.update_status(task_id:, status:, **_opts)
        task = Legion::Data::Model::Task[task_id]
        update = task.update(status: status)
        result = { success: true, task_id: task_id, status: status, previous_status: task.values[:status] }
        result[:changed] = update.nil? ? false : true
        result
      end
    end
  end
end
