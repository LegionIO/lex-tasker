# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Runners
        module TaskManager
          def purge_old(age: 31, limit: 100, status: 'task.completed', **_opts)
            log.debug("purging old completed tasks with an age > #{age} days, limit: #{limit}")
            cutoff = Time.now - (age * 86_400)
            dataset = Legion::Data::Model::Task
                      .where(Sequel.lit('created <= ?', cutoff))
                      .limit(limit)
            dataset = dataset.where(status: status) unless ['*', nil, ''].include?(status)
            log.debug "Deleting #{dataset.count} records" if dataset.any?
            dataset&.delete
          end

          def expire_queued(age: 1, limit: 10, **)
            cutoff = Time.now - (age * 3600)
            dataset = Legion::Data::Model::Task
                      .where(status: ['conditioner.queued', 'transformer.queued', 'task.queued'])
                      .where(Sequel.lit('created <= ?', cutoff))
                      .limit(limit)
            count = dataset.update(status: 'task.expired')
            { success: true, expired: count }
          end

          include Legion::Extensions::Helpers::Task
          include Legion::Extensions::Helpers::Lex
        end
      end
    end
  end
end
