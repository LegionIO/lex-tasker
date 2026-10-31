# lex-tasker

Task lifecycle coordination for [LegionIO](https://github.com/LegionIO/LegionIO): relationship-linked children, delayed dispatch, durable publication, guarded status updates, and task housekeeping. Tasker requires a connected `legion-data` database and transport. It does not execute business functions itself.

## Installation

```sh
gem install lex-tasker
```

Version 0.4.0 requires `legion-settings >= 1.5.0`, `legion-data >= 1.11.0`, and `legion-transport >= 1.4.32`. Actor mode requires **LegionIO >= 1.9.53** for trusted internal admission and guarded execution. Release/deploy Settings first, then Data/Transport, then Core, then Tasker and its pipeline peers. Run the new Data migrations before starting Tasker; existing published migrations must not be edited. The framework discovers the extension's runners, queues, and actors automatically. The standalone lookup client does not require loading Core, so the gem preserves the standard optional-Core dependency boundary.

`LEGION_MODE=lite` uses in-process transport; Tasker still requires a real database. Lite mode is useful for integration tests but does not make the in-process broker durable.

## Upgrading a delayed backlog

Stop Tasker consumers, relay actors, and task producers before upgrading; take a coordinated database backup. Apply Data migrations through 143 first, then let the framework run Tasker's extension migrations before activating its actors. Data 142 provides the real `task_logs` table and registered model; manually provisioned conflicting tables require operator reconciliation rather than silent schema adoption.

Tasker migration 001 creates a rollback journal. Migration 002 transactionally converts legacy flat delayed-task payloads into canonical envelopes using only the stored child snapshot and task row—not today's relationship definitions. Existing task IDs, results/input, conditions, transformation/engine, lineage, policy, and the earliest recorded deadline are preserved. Historical relationship/task delays use their maximum, matching the previous due-time rule. The outbox key is deterministic (`task:<id>:legacy-dispatch`). No broker publication occurs during migration.

If a historical snapshot lacks required target/input/template information or contains invalid data, migration 002 reports the affected task IDs and rolls back **all** conversions and journal entries. Migration 001 remains installed, so the failed conversion can be retried without schema guards. Recover the missing fields from trusted historical records or drain those tasks using the previous Tasker release, then retry. Do not substitute changed relationship definitions or delete the failed tasks to make startup appear successful. New runtime code accepts only canonical envelopes; it does not maintain a dual-format fallback.

Before any converted task is changed or dispatched, rolling Tasker's extension schema back restores the exact original task fields from the journal. Rollback refuses missing/modified tasks or any task with an outbox intent, leaves the data and journal intact, and identifies the blocking task. After work has advanced, use an operationally coordinated database restore rather than rolling schema versions backward. Keep the migration journal with the database backup until the release is accepted.

## Execution and durability

1. A completed task emits a durable `check_subtask` continuation. Tasker queries active relationships using real Sequel models and converts every row crossing a helper boundary to a plain Hash.
2. Each child has a deterministic identity derived from its parent task, relationship, and result-array index. The child and immediate outbox intent are committed atomically. Redelivering completion cannot create the same logical child twice, even after it finishes.
3. One canonical envelope carries `args`, `results`, original `function_args`, target function, conditions, transformation, engine/schema/options, parent/master/chain lineage, identity, tenant, correlation, depth, and deadline. Business arguments remain separate from control metadata.
4. Conditions run before transformations, otherwise the child goes directly to its function. Nonempty templates are meaningful; an explicitly selected engine also honors short static templates such as `{}`. Blank templates are not stages. ERB trust policy belongs to Transformer, not Tasker.
5. Positive delays store that exact envelope on the task. Polling later atomically changes a due task to `dispatching` and records its outbox intent. Editing a relationship after child creation does not rewrite the child's payload or route. Delays are finite, nonnegative seconds, rounded up to whole seconds for storage; missing delay uses the configured default.
6. The relay claims outbox leases, publishes with `publish!`, and acknowledges only an accepted publication. Failure releases the lease for recovery. A crash after broker acceptance but before acknowledgement can republish; downstream logical task claims and deterministic children make that redelivery safe. This is durable at-least-once handoff, not a claim of exactly-once arbitrary external effects.

Cancellation and the earliest inherited deadline are checked before child creation, delayed enqueue, and publication. A cancelled/expired pending intent is marked **discarded**, never delivered, and is not reclaimed repeatedly. Core checks eligibility again before executing a target. Depth and fanout limits reject oversized continuation batches before creating their children.

Delayed polling streams model rows, checks eligibility, then applies the configured eligible-batch limit. Long-delay rows at the front cannot starve later due rows. A large backlog with few due rows can require a full scan; rows are not eagerly materialized and broker publication is performed separately by the outbox relay.

## Runner and actor reference

All public runner methods use keyword arguments and return a Hash. Internal helpers may return other values.

| Runner | Methods | Operation |
|---|---|---|
| `CheckSubtask` | `check_subtasks(runner_class:, function:, task_id:, **context)` | Create/reuse relationship children and dispatch intents; returns counts and task IDs |
| `FetchDelayed` | `fetch(now: Time.now)`, `push` | Record due dispatches or publish a confirmed poll wakeup |
| `Outbox` | `dispatch_pending(owner: ..., limit: nil)` | Return `success`, `delivered`, `released`, and `discarded` counts |
| `Updater` | `update_status(task_id:, status: nil, expected_status: nil, token: nil, **values)` | Guard status and JSON field updates; terminal outcomes cannot regress |
| `TaskManager` | `expire_queued(age_seconds: nil, limit: nil)`, `recover_running(limit: nil)`, `purge_old(age_seconds: nil, limit: nil, status: nil)` | Expire stale queue work, mark abandoned execution `unknown`, or purge terminal tasks without pending continuations |
| `Log` | `add_log`, `delete_log`, `delete_task_logs`, `delete_node_logs`, `delete_all` | Task log persistence and deletion |

`FetchDelayedPush` periodically sends wakeups; `FetchDelayed` consumes them. `Outbox` independently polls durable intents. Stage actors bypass the generic business runner so orchestration cannot prematurely complete the eventual target task. Housekeeping functions are explicit operations; configure their invocation cadence through your deployment's scheduler.

The relay maps configured message types explicitly: `check_subtask` → CheckSubtask, `subtask` → SubTask, `task` → Task, `dynamic` → Dynamic, and `transform` → SubTask on the configured transform route. Unknown message types fail visibly and remain recoverable rather than evaluating arbitrary class names.

`recover_running` does not retry unknown external effects. Resolve an unknown outcome operationally before scheduling another execution. `purge_old` accepts only terminal statuses and retains tasks with pending/claimed continuation intents.

## Settings

Tasker uses `Legion::Settings::Helper` for `extensions.tasker` and `Legion::Settings::TaskExecution::Helper` for shared policy. Runtime overlays are respected; no runner duplicates shared status or route literals.

| Extension setting | Default |
|---|---:|
| `delayed_poll_interval_seconds` | `1` |
| `delayed_batch_size` (eligible work per poll) | `100` |
| `default_delay_seconds` | `0` |
| `empty_templates` | `["", "{}", "[]", "null"]` |
| `housekeeping.purge_age_seconds` | `2678400` (31 days) |
| `housekeeping.purge_limit` | `100` |
| `housekeeping.queued_age_seconds` | `3600` |
| `housekeeping.recovery_limit` | `100` |
| `housekeeping.queued_statuses` | `queued`, `conditioner_queued`, `transformer_queued`, `dispatching` |
| `housekeeping.prefetch` | `1` |

The `transport` section of `default_settings` defines Tasker's wakeup/housekeeping/log routes, queue names, wakeup TTL, and expiration. Shared `task_execution` defaults own canonical statuses, task routes, message types, terminal detection, maximum depth (`100`), fanout (`1000`), outbox lease (`30` seconds), batch size (`100`), and poll interval (`1` second). Publication defaults require publisher confirmation and mandatory routing and disable the separate transport spool because the outbox is already the durable source of truth.

## Standalone lookup client

```ruby
require 'legion/extensions/tasker/client'

client = Legion::Extensions::Tasker::Client.new
trigger = client.find_trigger(runner_class: 'Example::Source', function: 'produce')
relationships = client.find_subtasks(trigger_id: trigger.fetch(:function_id)) if trigger
client.find_delayed.each { |task| puts task.fetch(:id) }
```

The client uses configured, loaded Legion Data models. `find_delayed` returns a lazy enumerable of Hash rows. It does not fabricate a data model or silently hide a disconnected database. Tests use real Legion JSON/Logging/Settings, SQLite-backed models, the Data task-execution APIs, and in-process transport.

## Development

The Gemfile can use local companion checkouts from `.ci-dependencies/<repo>` (coordinated PR CI) or sibling worktrees when each matching gemspec exists. Production dependencies retain their minimum released API versions; no Git dependencies or compatibility fallbacks are used.

## License

MIT
