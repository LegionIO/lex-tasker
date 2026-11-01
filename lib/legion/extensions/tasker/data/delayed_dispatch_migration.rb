# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'
require 'legion/json/parse_error'

module Legion
  module Extensions
    module Tasker
      module Data
        module DelayedDispatchMigration
          extend self

          include Legion::Settings::Helper
          include Legion::Extensions::Tasker::Helpers::TaskFinder

          TASK_VALUES = %i[payload task_delay depth deadline_at].freeze
          REQUIRED_SNAPSHOT_FIELDS = %i[function runner_class runner_routing_key conditions transformation results payload].freeze

          def upgrade(db:)
            errors = []
            converted = 0
            db.transaction do
              db[:tasks].where(status: task_status(name: :delayed)).each do |task|
                snapshot = json_load(task.fetch(:payload))
                next if snapshot.is_a?(Hash) && snapshot[:options].is_a?(Hash) && snapshot[:event_key] && snapshot[:message_type]

                canonical = delayed_migration_values(task: task, snapshot: snapshot)
                db[:tasker_delayed_dispatch_backups].insert(task_id: task[:id], original_values: json_dump(task.slice(*TASK_VALUES)),
                                                            canonical_values: json_dump(canonical))
                db[:tasks].where(id: task[:id]).update(canonical)
                converted += 1
              rescue ArgumentError, TypeError, Legion::JSON::ParseError => e
                handle_exception(e, level: :error, handled: true, task_id: task[:id], operation: :migrate_delayed_dispatch)
                errors << "#{task[:id]}: #{e.message}"
              end
              unless errors.empty?
                raise ArgumentError, "Delayed dispatch migration rejected task IDs #{errors.join('; ')}. " \
                                     'Restore missing fields from a trusted historical payload or drain these tasks with the previous Tasker, ' \
                                     'then retry. No task changes were committed.'
              end
            end
            { converted: converted }
          end

          def rollback(db:)
            restored = 0
            db.transaction do
              db[:tasker_delayed_dispatch_backups].each do |backup|
                task = db[:tasks].where(id: backup[:task_id]).first
                canonical = delayed_migration_decode_values(values: backup[:canonical_values])
                if !task || task[:status] != task_status(name: :delayed) || task.slice(*TASK_VALUES) != canonical ||
                   db[:task_dispatches].where(task_id: backup[:task_id]).any?
                  raise ArgumentError, "Cannot roll back delayed task #{backup[:task_id]}: it was changed, dispatched, or removed. " \
                                       'Stop all workers and restore a coordinated database backup; no rollback changes were committed.'
                end

                db[:tasks].where(id: task[:id]).update(delayed_migration_decode_values(values: backup[:original_values]))
                restored += 1
              end
              db[:tasker_delayed_dispatch_backups].delete
            end
            { restored: restored }
          end

          private

          def delayed_migration_values(task:, snapshot:)
            raise ArgumentError, 'stored child payload is not a Hash' unless snapshot.is_a?(Hash)

            missing = REQUIRED_SNAPSHOT_FIELDS.reject { |key| snapshot.key?(key) }
            raise ArgumentError, "missing historical fields #{missing.join(', ')}" unless missing.empty?
            unless %i[function runner_class runner_routing_key].all? { |key| snapshot[key].is_a?(String) && !snapshot[key].strip.empty? }
              raise ArgumentError, 'historical target function, runner_class, and runner_routing_key must be nonempty strings'
            end
            raise ArgumentError, 'historical parent payload is not a Hash' unless snapshot[:payload].is_a?(Hash)
            if snapshot[:function_id] && snapshot[:function_id] != task[:function_id]
              raise ArgumentError, 'historical function_id disagrees with the stored task'
            end

            delays = [snapshot[:delay], task[:task_delay]].compact
            raise ArgumentError, 'historical delay is absent' if delays.empty?

            delay = delays.map { |value| tasker_delay_seconds(delay: value) }.max.ceil
            envelope = delayed_migration_envelope(task: task, snapshot: snapshot)
            stage = tasker_stage(envelope: envelope)
            envelope[:routing_key] = stage[:routing_key]
            dispatch = { event_key: "task:#{task[:id]}:legacy-dispatch", message_type: stage[:message_type], options: envelope }
            { payload: json_dump(dispatch), task_delay: delay, depth: envelope[:depth], deadline_at: envelope[:deadline_at] }
          end

          def delayed_migration_envelope(task:, snapshot:)
            parent = snapshot.fetch(:payload)
            fields = Legion::Transport::TaskProtocol::METADATA_FIELDS
            envelope = parent.slice(*fields).merge(snapshot.except(:payload, :delay, :status, :success)).except(:attempt_id, :execution_token)
            envelope.merge!(task_id: task[:id], function_id: task[:function_id], relationship_id: task[:relationship_id],
                            parent_id: task[:parent_id], master_id: task[:master_id], depth: snapshot.fetch(:depth, task[:depth]))
            original_args = snapshot.fetch(:function_args) { parent.fetch(:function_args, parent.fetch(:args, {})) }
            original_args = json_load(original_args) if original_args.is_a?(String)
            raise ArgumentError, 'historical function_args are not a Hash' unless original_args.is_a?(Hash)

            envelope[:function_args] = original_args
            envelope[:args] = snapshot[:results].is_a?(Hash) ? snapshot[:results] : original_args
            deadlines = [task[:deadline_at], snapshot[:deadline_at], parent[:deadline_at]].compact
            envelope[:deadline_at] = deadlines.map do |value|
              deadline = value.is_a?(String) ? Time.parse(value) : value
              deadline.is_a?(Time) ? deadline.getlocal : deadline
            end.min
            envelope
          end

          def delayed_migration_decode_values(values:)
            decoded = json_load(values)
            decoded[:deadline_at] = Time.parse(decoded[:deadline_at]).getlocal if decoded[:deadline_at].is_a?(String)
            decoded
          end
        end
      end
    end
  end
end
