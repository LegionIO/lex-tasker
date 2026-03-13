# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Runners
        module Updater
          include Legion::Extensions::Helpers::Lex

          def update_status(task_id:, **opts)
            task = Legion::Data::Model::Task[task_id]
            return { success: false, changed: false, task_id: task_id, message: 'task nil' } if task.nil? || task.values.nil?

            log.unknown task.class

            update_hash = {}
            %i[status function_args payload results].each do |column|
              next unless opts.key? column

              update_hash[column] = if opts[column].is_a? String
                                      opts[column]
                                    else
                                      to_json opts[column]
                                    end
            end
            { success: true, changed: false, task_id: task_id } if update_hash.none?
            task.update(update_hash)

            { success: true, changed: true, task_id: task_id, updates: update_hash }
          end
        end
      end
    end
  end
end
