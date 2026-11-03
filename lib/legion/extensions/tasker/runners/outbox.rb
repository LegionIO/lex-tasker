# frozen_string_literal: true

require 'securerandom'
require 'legion/extensions/tasker/helpers/task_finder'
require 'legion/transport/messages/check_subtask'
require 'legion/transport/messages/subtask'
require 'legion/transport/messages/task'
require 'legion/transport/messages/dynamic'

module Legion
  module Extensions
    module Tasker
      module Runners
        module Outbox
          extend self

          include Legion::Extensions::Tasker::Helpers::TaskFinder

          MESSAGE_TYPES = {
            check_subtask: Legion::Transport::Messages::CheckSubtask,
            subtask:       Legion::Transport::Messages::SubTask,
            task:          Legion::Transport::Messages::Task,
            dynamic:       Legion::Transport::Messages::Dynamic,
            transform:     Legion::Transport::Messages::SubTask
          }.freeze

          def dispatch_pending(owner: SecureRandom.uuid, limit: nil, **)
            counts = { success: true, delivered: 0, released: 0, discarded: 0 }
            Legion::Data::TaskExecution.claim_dispatches(owner: owner, limit: limit).each do |dispatch|
              tasker_deliver_dispatch(dispatch: dispatch, counts: counts)
            end
            counts[:success] = counts[:released].zero?
            counts
          end

          private

          def tasker_deliver_dispatch(dispatch:, counts:)
            task = Legion::Data::Model::Task[dispatch[:task_id]] if dispatch[:task_id]
            if task && tasker_discard_dispatch(dispatch: dispatch, task: task)
              counts[:discarded] += 1
              return
            end

            type = Legion::Transport::TaskProtocol::MESSAGE_TYPES.key(dispatch[:message_type])
            klass = MESSAGE_TYPES.fetch(type)
            options = dispatch.fetch(:options)
            options = options.merge(routing_key: task_route(name: :transform)) if type == :transform
            result = klass.new(**options).publish!
            raise IOError, 'publication was not accepted' unless result.is_a?(Hash) && result[:accepted] == true

            if task && task[:status] == task_status(name: :dispatching)
              route = options[:routing_key]
              stage = if route == task_route(name: :conditioner)
                        :conditioner_queued
                      elsif route == task_route(name: :transform)
                        :transformer_queued
                      else
                        :queued
                      end
              Legion::Data::TaskExecution.transition_task(task_id: task[:id], status: task_status(name: stage),
                                                          expected_status: task_status(name: :dispatching))
            end

            acknowledgement = Legion::Data::TaskExecution.ack_dispatch(dispatch_id: dispatch[:id], token: dispatch[:token])
            raise IOError, "dispatch #{dispatch[:id]} lost acknowledgement lease" unless acknowledgement[:changed]

            counts[:delivered] += 1
          rescue StandardError => e
            handle_exception(e, level: :warn, handled: true, dispatch_id: dispatch[:id], task_id: dispatch[:task_id])
            Legion::Data::TaskExecution.release_dispatch(dispatch_id: dispatch[:id], token: dispatch[:token], error: e.message)
            counts[:released] += 1
          end

          def tasker_discard_dispatch(dispatch:, task:)
            blocked = tasker_blocked_status(task: task.values, now: Time.now)
            parent = Legion::Data::Model::Task[task[:parent_id]] if task[:parent_id]
            blocked ||= tasker_blocked_status(task: parent.values, now: Time.now) if parent
            return false unless blocked

            discarded = Legion::Data.connection.transaction do
              Legion::Data::TaskExecution.transition_task(task_id: task[:id], status: blocked, expected_status: task[:status])
              Legion::Data::TaskExecution.discard_dispatch(dispatch_id: dispatch[:id], token: dispatch[:token], reason: blocked)
            end
            raise IOError, "dispatch #{dispatch[:id]} lost discard lease" unless discarded[:changed]

            true
          end
        end
      end
    end
  end
end
