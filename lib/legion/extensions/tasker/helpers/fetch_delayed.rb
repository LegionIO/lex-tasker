module Legion
  module Extensions
    module Tasker
      module Helpers
        module FetchDelayed
          def find_trigger(runner_class:, function:, **)
            sql = "SELECT `functions`.`id` as `function_id`, `runner_id`, `runners`.`namespace`
                   FROM `legion`.`functions`
                     INNER JOIN `legion`.`runners` ON (`functions`.`runner_id` = `runners`.`id`)
                    WHERE `functions`.`name` = '#{function}'
                     AND `runners`.`namespace` = '#{runner_class}' LIMIT 1;"

            cache = Legion::Cache.get(sql)
            return cache unless cache.nil?

            results = Legion::Data::Connection.sequel.fetch(sql).first
            Legion::Cache.set(sql, results) if results.is_a?(Hash) && results.count.positive?
            results
          end

          def find_delayed(**)
            sql = '
              SELECT tasks.id, tasks.relationship_id, tasks.function_id, tasks.created,
                relationships.delay as relationship_delay, relationships.chain_id,
                functions.name as function_name,
                runners.namespace as class, runners.id as runner_id,
                CONCAT( `exchange`, ".",`queue`,".",`functions`.`name`) AS runner_routing_key
              FROM legion.tasks
                INNER JOIN legion.functions ON (functions.id = tasks.function_id)
                INNER JOIN legion.runners ON (runners.id = functions.runner_id)
                INNER JOIN `legion`.`extensions` ON (`runners`.`extension_id` = `extensions`.`id`)
                LEFT JOIN legion.relationships ON (relationships.id = tasks.relationship_id)
              WHERE status = \'task.delayed\';'

            Legion::Data::Connection.sequel.fetch(sql)
          end

          def find_subtasks(trigger_id:, **)
            sql = "
              SELECT
               `relationships`.`id` as `relationship_id`, `debug`,
               `chain_id`, `allow_new_chains`, `delay`, `trigger_id`, `action_id`, `conditions`, `transformation`,
               `runners`.`namespace`, `runners`.`id` as `runner_id`, `runners`.`queue`,
               `runners`.`namespace` as runner_class,
               `functions`.`id` as `function_id`, `functions`.`name` as `function`,
               `extensions`.`exchange`,
               CONCAT( `exchange`, '.',`queue`,'.',`functions`.`name`) AS runner_routing_key
              FROM `legion`.`relationships`
                INNER JOIN `legion`.`functions` ON (`functions`.`id` = `relationships`.`action_id`)
                INNER JOIN `legion`.`runners` ON (`functions`.`runner_id` = `runners`.`id`)
                INNER JOIN `legion`.`extensions` ON (`runners`.`extension_id` = `extensions`.`id`)
              WHERE `relationships`.`trigger_id` = #{trigger_id} AND `relationships`.`active` = 1;
            "

            cache = Legion::Cache.get(sql)
            return cache unless cache.nil?

            results = Legion::Data::Connection.sequel.fetch(sql)
            Legion::Cache.set(sql, results, ttl: 5) if results.is_a?(Hash) && results.count.positive?
            results
          end
        end
      end
    end
  end
end
