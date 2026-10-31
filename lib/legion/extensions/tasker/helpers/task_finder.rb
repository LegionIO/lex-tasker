# frozen_string_literal: true

require 'legion/extensions/tasker'
require 'legion/data'
require 'legion/data/task_execution'
require 'legion/json/helper'
require 'time'

module Legion
  module Extensions
    module Tasker
      module Helpers
        module TaskFinder
          include Legion::Logging::Helper
          include Legion::Settings::Helper
          include Legion::Transport::TaskProtocol::Helper
          include Legion::JSON::Helper

          def find_trigger(runner_class:, function:, **)
            row = Legion::Data::Model::Function
                  .join(:runners, id: :runner_id)
                  .where(Sequel[:functions][:name] => function, Sequel[:runners][:namespace] => runner_class.to_s)
                  .select(Sequel[:functions][:id].as(:function_id), Sequel[:functions][:runner_id])
                  .first
            row&.values&.dup
          end

          def find_subtasks(trigger_id:, **)
            Legion::Data::Model::Relationship
              .join(:functions, id: :action_id)
              .join(:runners, id: Sequel[:functions][:runner_id])
              .join(:extensions, id: Sequel[:runners][:extension_id])
              .where(Sequel[:relationships][:trigger_id] => trigger_id, Sequel[:relationships][:active] => true)
              .select_all(:relationships)
              .select_append(Sequel[:relationships][:id].as(:relationship_id),
                             Sequel[:runners][:id].as(:runner_id), Sequel[:runners][:queue],
                             Sequel[:runners][:namespace].as(:runner_class),
                             Sequel[:functions][:id].as(:function_id), Sequel[:functions][:name].as(:function),
                             Sequel[:extensions][:exchange])
              .order(Sequel[:relationships][:id]).all.map do |row|
                values = row.values.dup
                values[:runner_routing_key] = "#{values[:exchange]}.#{values[:queue]}.#{values[:function]}"
                values
              end
          end

          def find_delayed(**)
            Legion::Data::Model::Task.where(status: task_status(name: :delayed))
                                     .order(:created, :id).to_enum(:each).lazy.map { |row| row.values.dup }
          end

          private

          def tasker_delay_seconds(delay:)
            value = delay.nil? ? settings.fetch(:default_delay_seconds) : Float(delay)
            raise ArgumentError, 'task delay must be finite and nonnegative' unless value.finite? && value >= 0

            value
          end

          def tasker_template_present?(template:, engine: nil)
            return !template.empty? if template.is_a?(Hash) || template.is_a?(Array)
            return false if template.nil?
            raise ArgumentError, 'task template must be a String, Hash or Array' unless template.is_a?(String)

            text = template.strip
            return false if text.empty?
            return true unless engine.to_s.strip.empty?

            !settings.fetch(:empty_templates).include?(text)
          end

          def tasker_stage(envelope:)
            types = Legion::Transport::TaskProtocol::MESSAGE_TYPES
            if tasker_template_present?(template: envelope[:conditions])
              { status: task_status(name: :conditioner_queued), routing_key: task_route(name: :conditioner), message_type: types.fetch(:subtask) }
            elsif tasker_template_present?(template: envelope[:transformation], engine: envelope[:engine])
              { status: task_status(name: :transformer_queued), routing_key: task_route(name: :transform), message_type: types.fetch(:transform) }
            else
              { status: task_status(name: :queued), routing_key: envelope.fetch(:runner_routing_key), message_type: types.fetch(:dynamic) }
            end
          end

          def tasker_blocked_status(task:, now:)
            return task_status(name: :cancelled) if task[:cancelled_at] || task[:status] == task_status(name: :cancelled)
            return task_status(name: :expired) if task[:status] == task_status(name: :expired)

            deadline = task[:deadline_at]
            deadline = Time.parse(deadline) if deadline.is_a?(String)
            task_status(name: :expired) if deadline && deadline <= now
          end

          def tasker_dispatch_from_task(task:)
            payload = task[:payload].is_a?(String) ? json_load(task[:payload]) : task[:payload]
            raise ArgumentError, "task #{task[:id]} has no stored dispatch envelope" unless payload.is_a?(Hash) && payload[:options].is_a?(Hash)

            payload.merge(options: payload[:options].merge(task_id: task[:id]))
          end
        end
      end
    end
  end
end
