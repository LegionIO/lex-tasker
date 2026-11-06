# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'
require 'legion/extensions/tasker/transport/messages/fetch_delayed'

module Legion
  module Extensions
    module Tasker
      module Runners
        module FetchDelayed
          extend self # -- Runner module methods need the included helpers.

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          DISPATCH_STATUSES = { 'dynamic' => :queued, 'subtask' => :conditioner_queued, 'transform' => :transformer_queued }.freeze

          def fetch(now: Time.now, **)
            counts = { success: true, dispatched: 0, cancelled: 0, expired: 0 }
            limit = settings.fetch(:delayed_batch_size)
            tasker_find_delayed.each do |task|
              break if counts.values_at(:dispatched, :cancelled, :expired).sum >= limit

              parent = task[:parent_id] ? Legion::Data::Model::Task[task[:parent_id]] : nil
              blocked = tasker_blocked_status(task: task)
              blocked ||= tasker_blocked_status(task: parent.values) if parent
              if blocked
                changed = Legion::Data::Model::Task.where(id: task[:id], status: task_status(name: :delayed)).update(status: blocked)
                counts[blocked == task_status(name: :cancelled) ? :cancelled : :expired] += changed
                next
              end
              next if task[:created] + tasker_delay_seconds(delay: task[:task_delay]) > now

              dispatch = tasker_dispatch_from_task(task: task)
              tasker_publish(**dispatch)
              status = DISPATCH_STATUSES.fetch(dispatch[:message_type])
              Legion::Data::Model::Task.where(id: task[:id], status: task_status(name: :delayed)).update(status: task_status(name: status))
              counts[:dispatched] += 1
            end
            counts
          end

          def push(**)
            Legion::Extensions::Tasker::Transport::Messages::FetchDelayed.new.publish!
            { success: true }
          end
        end
      end
    end
  end
end
