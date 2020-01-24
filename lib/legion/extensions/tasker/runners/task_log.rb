require 'legion/data/models/task_log'

module Legion
  module Extensions
    module Tasker
      module Runners
        class TaskLog
          def self.add_log(payload)
            log = Legion::Data::Model::TaskLog
            insert = { task_id: payload[:task_id] }
            insert[:log] = payload[:log]
            if payload.key?(:node_id)
              insert[:node_id] = payload[:node_id]
            else
              # we should search for the node here but I don't want to write the code
            end
            id = log.insert(insert)

            result = { success: !id.nil?, id: id }
            result
          end

          def self.delete_log(payload); end

          def self.delete_all_task_logs(payload); end
        end
      end
    end
  end
end
