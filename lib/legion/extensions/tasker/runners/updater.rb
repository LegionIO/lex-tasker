# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      module Runners
        module Updater
          extend self

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def update_status(task_id:, status: nil, expected_status: nil, token: nil, **opts)
            task = Legion::Data::Model::Task[task_id]
            return { success: false, changed: false, task_id: task_id, reason: :missing } unless task

            values = opts.slice(:function_args, :payload, :results)
            result = Legion::Data::TaskExecution.transition_task(task_id: task_id, status: status || task[:status],
                                                                 expected_status: expected_status, token: token, values: values)
            { success: result[:changed] || task_terminal_status?(status: result[:task][:status]), task_id: task_id, **result }
          end
        end
      end
    end
  end
end
