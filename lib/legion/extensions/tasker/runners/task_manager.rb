# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      module Runners
        module TaskManager
          extend self

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def purge_old(age_seconds: nil, limit: nil, status: nil, now: Time.now, **)
            policy = settings.fetch(:housekeeping)
            age_seconds ||= policy.fetch(:purge_age_seconds)
            limit ||= policy.fetch(:purge_limit)
            status ||= task_status(name: :completed)
            raise ArgumentError, 'only terminal tasks may be purged' unless task_terminal_status?(status: status)
            raise ArgumentError, 'purge age must be positive' unless age_seconds.positive?

            pending_statuses = task_execution_settings.fetch(:outbox).fetch(:statuses).values_at(:pending, :claimed)
            pending = Legion::Data.connection[:task_dispatches].where(status: pending_statuses).exclude(task_id: nil).select(:task_id)
            ids = Legion::Data::Model::Task.where(status: status).where { created <= now - age_seconds }
                                           .exclude(id: pending).order(:created, :id).limit(limit).select_map(:id)
            deleted = Legion::Data::Model::Task.where(id: ids, status: status).delete
            { success: true, deleted: deleted }
          end

          def expire_queued(age_seconds: nil, limit: nil, now: Time.now, **)
            policy = settings.fetch(:housekeeping)
            age_seconds ||= policy.fetch(:queued_age_seconds)
            limit ||= policy.fetch(:recovery_limit)
            statuses = policy.fetch(:queued_statuses).map { |name| task_status(name: name) }
            tasks = Legion::Data::Model::Task.where(status: statuses).where { created <= now - age_seconds }
                                             .order(:created, :id).limit(limit).all
            counts = { success: true, expired: 0, cancelled: 0 }
            tasks.each do |task|
              status = tasker_blocked_status(task: task.values, now: now) || task_status(name: :expired)
              result = Legion::Data::TaskExecution.transition_task(task_id: task[:id], status: status, expected_status: task[:status])
              next unless result[:changed] || result[:task][:status] == status

              counts[status == task_status(name: :cancelled) ? :cancelled : :expired] += 1
            end
            counts
          end

          def recover_running(limit: nil, now: Time.now, **)
            limit ||= settings.fetch(:housekeeping).fetch(:recovery_limit)
            tasks = Legion::Data::Model::Task.where(status: task_status(name: :running))
                                             .where(Sequel.|({ execution_lease_until: nil }, Sequel[:execution_lease_until] <= now))
                                             .order(:id).limit(limit).all
            count = tasks.count do |task|
              result = Legion::Data::TaskExecution.transition_task(task_id: task[:id], status: task_status(name: :unknown),
                                                                   expected_status: task[:status], token: task[:execution_token])
              result[:task][:status] == task_status(name: :unknown)
            end
            { success: true, unknown: count }
          end
        end
      end
    end
  end
end
