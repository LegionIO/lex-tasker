# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'
require 'legion/extensions/tasker/transport/messages/fetch_delayed'

module Legion
  module Extensions
    module Tasker
      module Runners
        module FetchDelayed
          extend self

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          def fetch(now: Time.now, **)
            counts = { success: true, dispatched: 0, cancelled: 0, expired: 0 }
            limit = settings.fetch(:delayed_batch_size)
            find_delayed.each do |task|
              break if counts.values_at(:dispatched, :cancelled, :expired).sum >= limit

              parent = Legion::Data::Model::Task[task[:parent_id]] if task[:parent_id]
              blocked = tasker_blocked_status(task: task, now: now)
              blocked ||= tasker_blocked_status(task: parent.values, now: now) if parent
              if blocked
                transition = Legion::Data::TaskExecution.transition_task(task_id: task[:id], status: blocked,
                                                                         expected_status: task_status(name: :delayed))
                if transition[:changed] || transition[:task][:status] == blocked
                  counts[blocked == task_status(name: :cancelled) ? :cancelled : :expired] += 1
                end
                next
              end
              next if task[:created] + tasker_delay_seconds(delay: task[:task_delay]) > now

              dispatch = tasker_dispatch_from_task(task: task)
              outcome = Legion::Data::TaskExecution.enqueue_task_dispatch(task_id:         task[:id], **dispatch,
                                                                          expected_status: task_status(name: :delayed))
              counts[:dispatched] += 1 if outcome[:created]
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
