require 'legion/data/models/task'

module Legion
  module Extensions
    module Tasker
      module Runners
        class TaskUpdater
          def self.update_status(payload)
            task = Legion::Data::Model::Task[payload[:task_id]]
            update = task.update(status: payload[:status])
            result = { success: true }
            result[:task_id] = payload[:task_id]
            result[:previous_status] = task.values[:status]
            result[:status] = payload[:status]
            result[:changed] = if update.nil?
                                 false
                               else
                                 true
                               end
            result
          end
        end
      end
    end
  end
end
