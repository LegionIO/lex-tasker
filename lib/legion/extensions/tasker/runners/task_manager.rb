# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      module Runners
        module TaskManager
          extend self # -- Runner module methods need the included helpers.

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def generate_task_id(function_id:, status: task_status(name: :queued), **opts)
            values = opts.slice(:master_id, :parent_id, :relationship_id, :task_delay, :depth, :cancelled_at)
                         .merge(function_id: function_id, status: status)
            values[:payload] = opts[:payload].is_a?(String) ? opts[:payload] : json_dump(opts[:payload]) if opts.key?(:payload)
            values[:function_args] = opts[:args].is_a?(String) ? opts[:args] : json_dump(opts[:args]) if opts.key?(:args)
            task = Legion::Data::Model::Task.create(values)
            { **task.values, success: true, task_id: task.id }
          end

          def purge_old(age_seconds: nil, limit: nil, status: nil, now: Time.now, **)
            policy = settings.fetch(:housekeeping)
            age_seconds ||= policy.fetch(:purge_age_seconds)
            limit ||= policy.fetch(:purge_limit)
            status ||= task_status(name: :completed)
            raise ArgumentError, 'only terminal tasks may be purged' unless task_terminal_status?(status: status)
            raise ArgumentError, 'purge age must be positive' unless age_seconds.positive?

            ids = Legion::Data::Model::Task.where(status: status).where { created <= now - age_seconds }
                                                                 .order(:created, :id).limit(limit).select_map(:id)
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
              status = tasker_blocked_status(task: task.values) || task_status(name: :expired)
              changed = Legion::Data::Model::Task.where(id: task.id, status: task[:status], cancelled_at: task[:cancelled_at]).update(status: status)
              counts[status == task_status(name: :cancelled) ? :cancelled : :expired] += changed
            end
            counts
          end
        end
      end
    end
  end
end
