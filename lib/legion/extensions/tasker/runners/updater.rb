# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      module Runners
        module Updater
          extend self # -- Runner module methods need the included helpers.

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def update_status(task_id:, **opts)
            task = Legion::Data::Model::Task[task_id]
            return { success: false, changed: false, task_id: task_id, reason: :missing } unless task

            values = opts.slice(:status, :function_args, :payload, :results, :cancelled_at)
            %i[function_args payload results].each do |column|
              values[column] = json_dump(values[column]) if values.key?(column) && !values[column].is_a?(String)
            end
            return { success: true, changed: false, task_id: task_id } if values.empty?

            task.update(values)
            { success: true, changed: true, task_id: task_id, updates: values, task: task.values }
          end
        end
      end
    end
  end
end
