# frozen_string_literal: true

module Legion
  module Extensions
    module Tasker
      module Helpers
        module TaskFinder
          def cache_get(key)
            return nil unless defined?(Legion::Cache) && Legion::Cache.respond_to?(:connected?) && cache_connected?

            Legion::Cache.get("tasker:#{key}") # rubocop:disable Legion/HelperMigration/DirectCache
          rescue StandardError => _e
            nil
          end

          def cache_set(key, value, ttl: 60)
            return unless defined?(Legion::Cache) && Legion::Cache.respond_to?(:connected?) && cache_connected?

            Legion::Cache.set("tasker:#{key}", value, ttl) # rubocop:disable Legion/HelperMigration/DirectCache
          rescue StandardError => _e
            nil
          end

          def find_trigger(runner_class:, function:, **)
            return nil unless defined?(Legion::Data::Model::Function)

            cache_key = "find_trigger:#{runner_class}:#{function}"
            cached = cache_get(cache_key)
            return cached if cached.is_a?(Hash)

            result = Legion::Data::Model::Function
                     .join(:runners, id: :runner_id)
                     .where(Sequel[:functions][:name]    => function,
                            Sequel[:runners][:namespace] => runner_class)
                     .select(Sequel[:functions][:id].as(:function_id),
                             Sequel[:functions][:runner_id],
                             Sequel[:runners][:namespace])
                     .first

            cache_set(cache_key, result) if result
            result
          end

          def find_subtasks(trigger_id:, **)
            return [] unless defined?(Legion::Data::Model::Relationship)

            cache_key = "find_subtasks:#{trigger_id}"
            cached = cache_get(cache_key)
            return cached if cached.is_a?(Array)

            results = subtask_query(trigger_id).all.map do |row|
              row[:runner_routing_key] = "#{row[:exchange]}.#{row[:queue]}.#{row[:function]}"
              row
            end

            cache_set(cache_key, results, ttl: 5) if results.is_a?(Array) && results.any?
            results
          end

          def find_delayed(**)
            return [] unless defined?(Legion::Data::Model::Task)

            Legion::Data::Model::Task
              .join(:functions, id: :function_id)
              .join(:runners, id: Sequel[:functions][:runner_id])
              .join(:extensions, id: Sequel[:runners][:extension_id])
              .left_join(:relationships, id: Sequel[:tasks][:relationship_id])
              .where(Sequel[:tasks][:status] => 'task.delayed')
              .select(
                Sequel[:tasks][:id],
                Sequel[:tasks][:relationship_id],
                Sequel[:tasks][:function_id],
                Sequel[:tasks][:created],
                Sequel[:relationships][:delay].as(:relationship_delay),
                Sequel[:relationships][:chain_id],
                Sequel[:functions][:name].as(:function_name),
                Sequel[:runners][:namespace].as(:runner_class),
                Sequel[:runners][:id].as(:runner_id),
                Sequel[:runners][:queue],
                Sequel[:extensions][:exchange],
                Sequel[:tasks][:task_delay]
              ).all.map do |task|
                task[:runner_routing_key] = "#{task[:exchange]}.#{task[:queue]}.#{task[:function_name]}"
                task
              end
          end

          private

          def subtask_query(trigger_id)
            Legion::Data::Model::Relationship
              .join(:functions, id: :action_id)
              .join(:runners, id: Sequel[:functions][:runner_id])
              .join(:extensions, id: Sequel[:runners][:extension_id])
              .where(Sequel[:relationships][:trigger_id] => trigger_id,
                     Sequel[:relationships][:active]     => true)
              .select(
                Sequel[:relationships][:id].as(:relationship_id),
                Sequel[:relationships][:debug],
                Sequel[:relationships][:chain_id],
                Sequel[:relationships][:allow_new_chains],
                Sequel[:relationships][:delay],
                Sequel[:relationships][:trigger_id],
                Sequel[:relationships][:action_id],
                Sequel[:relationships][:conditions],
                Sequel[:relationships][:transformation],
                Sequel[:runners][:namespace],
                Sequel[:runners][:id].as(:runner_id),
                Sequel[:runners][:queue],
                Sequel[:runners][:namespace].as(:runner_class),
                Sequel[:functions][:id].as(:function_id),
                Sequel[:functions][:name].as(:function),
                Sequel[:extensions][:exchange]
              )
          end
        end
      end
    end
  end
end
