module Legion
  module Extensions
    module Tasker
      module Runners
        module TaskManager
          def purge_old(age: 31, limit: 100, status: 'task.completed', **_opts)
            log.debug("purging old completed tasks with an age > #{age} days, limit: #{limit}")
            dataset = Legion::Data::Model::Task
                      .where(Sequel.lit("created <= DATE_SUB(SYSDATE(), INTERVAL #{age} DAY)"))
                      .limit(limit)
            dataset.where(status: status) unless ['*', nil, ''].include? status
            log.debug "Deleting #{dataset.count} records" if dataset.count.positive?
            dataset&.delete
          end

          def expire_queued(age: 1, limit: 10, **) # rubocop:disable Lint/UnusedMethodArgument
            dataset = Legion::Data::Model::Task # rubocop:disable Lint/UselessAssignment
                      .where(status: ['conditioner.queued', 'transformer.queued', 'task.queued'])
                      .limit(limit)
          end

          include Legion::Extensions::Helpers::Task
          include Legion::Extensions::Helpers::Lex
        end
      end
    end
  end
end
