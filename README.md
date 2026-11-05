# lex-tasker

Task persistence and routing for [LegionIO](https://github.com/LegionIO/LegionIO): relationship-linked children, delayed publication, status updates, and task housekeeping. Tasker requires a connected `legion-data` database and transport. It does not execute business functions itself.

## Installation

```sh
gem install lex-tasker
```

Version 0.4.0 requires `legion-settings >= 1.4.5`, `legion-data >= 1.11.0`, and `legion-transport >= 1.4.32`. Actor mode requires **LegionIO >= 1.9.53** for trusted internal admission and persistence-error propagation. Release/deploy Settings first, then Data/Transport, then Core, then Tasker and its pipeline peers. Run Data migrations before starting Tasker. The framework discovers the extension's runners, queues, and actors automatically. The standalone lookup client does not require Core.

`LEGION_MODE=lite` uses in-process transport; Tasker still requires a real database. Lite mode is useful for integration tests but does not make the in-process broker durable.

## Upgrading a delayed backlog

Drain delayed tasks created by earlier Tasker versions before upgrading, then stop consumers and producers and back up the database. The new runtime stores one canonical publication envelope on each delayed task; it does not reconstruct old payloads from changed relationship definitions. There are no Tasker-specific coordination migrations, rollback journals, or additional dispatch tables.

## Persistence and publication

Each persistence delivery creates or updates one ordinary `Legion::Data::Model::Task` row. Consumers use prefetch 1. Database errors propagate to the consumer rather than returning a successful persistence result. There are no execution claims, attempts, leases, or outbox actors.

1. A completion message invokes `check_subtasks`. Tasker reads active relationships using real Sequel models and returns plain Hashes across helper boundaries.
2. Each matching relationship and result creates one child with inherited identity, input, schema, and parent/master/chain lineage.
3. Conditions run before transformations; otherwise the child goes directly to its function. An explicit engine honors short static templates such as `{}`. Blank templates are not stages. ERB trust policy belongs to Transformer.
4. Immediate children publish directly with `publish!`. Delayed children store `status: 'task.delayed'`, `task_delay` in rounded-up seconds, and JSON `payload: { message_type:, options: }`. Options contain the complete target envelope, including arguments, templates, routing, and lineage.
5. `fetch(now:)` reads delayed rows, checks task and parent cancellation, and publishes due envelopes with the persisted task ID. Only after publication succeeds does it update the row to the appropriate queued status. Relationship edits do not change stored envelopes.

Delays must be finite and nonnegative. Cancelled or already expired tasks are not published. Depth/fanout limits are checked before creating children. The delayed poll limit counts eligible rows, so an older long-delay task cannot starve later due work.

Database writes and broker publication are separate operations, not a distributed transaction. A failed immediate publication can leave its created row behind. A failed delayed publication leaves the row delayed; a crash after broker acceptance but before its status update can publish it again. Redelivered completion can create additional children. There is no exactly-once or automatic external-effect recovery guarantee.

## Runner and actor reference

All public runner methods use keyword arguments and return a Hash. Internal helpers may return other values.

| Runner | Methods | Operation |
|---|---|---|
| `CheckSubtask` | `check_subtasks(runner_class:, function:, task_id:, **context)` | Create and publish relationship children; return counts and task IDs |
| `FetchDelayed` | `fetch(now: Time.now)`, `push` | Publish due tasks or a poll wakeup; return dispatched/cancelled/expired counts |
| `Updater` | `update_status(task_id:, **values)` | Update one row's status, JSON fields, or cancellation; return success/changed/task_id and updated values |
| `TaskManager` | `generate_task_id(function_id:, status: 'task.queued', **values)` | Create one task; return its values, success, and task_id |
| `TaskManager` | `expire_queued(age_seconds: nil, limit: nil)`, `purge_old(age_seconds: nil, limit: nil, status: nil)` | Expire stale queued work or purge aged terminal tasks |
| `Log` | `add_log`, `delete_log`, `delete_task_logs`, `delete_node_logs`, `delete_all` | Task log persistence and deletion |

`FetchDelayedPush` periodically sends wakeups; `FetchDelayed` consumes them. Internal actors bypass the generic business runner so persistence and orchestration cannot prematurely complete the eventual target task. Configure housekeeping cadence through your deployment's scheduler.

`generate_task_id` accepts `args` and `payload` and serializes them into `function_args` and `payload`. `update_status` accepts `status`, `function_args`, `payload`, `results`, and `cancelled_at`. JSON fields may be Ruby values or already serialized strings. An update of a missing task returns `success: false`; an update with no supported fields returns `changed: false`. Status updates are ordinary writes, not guarded execution transitions.

## Settings

Tasker reads dynamic process-local policy from `Legion::Settings[:extensions][:tasker]` through the settings helper injected by the framework. Defaults are registered at boot, not on each read. Statuses, routes, message types, and metadata use `Legion::Transport::Task::Protocol`; settings cannot rename persisted or wire identities.

| Extension setting | Default |
|---|---:|
| `delayed_poll_interval_seconds` | `1` |
| `delayed_batch_size` (eligible work per poll) | `100` |
| `default_delay_seconds` | `0` |
| `empty_templates` | `["", "{}", "[]", "null"]` |
| `execution.max_depth` | `100` |
| `execution.max_fanout` | `1000` |
| `housekeeping.purge_age_seconds` | `2678400` (31 days) |
| `housekeeping.purge_limit` | `100` |
| `housekeeping.queued_age_seconds` | `3600` |
| `housekeeping.recovery_limit` | `100` |
| `housekeeping.queued_statuses` | `queued`, `conditioner_queued`, `transformer_queued` |

The `transport` section of `default_settings` defines Tasker's wakeup/housekeeping/log routes, queue names, wakeup TTL, and expiration. Transport owns publication policy under `transport.task_publication`; Tasker uses `publish!` without overriding those settings.

## Standalone lookup client

```ruby
require 'legion/extensions/tasker/client'

client = Legion::Extensions::Tasker::Client.new
trigger = client.find_trigger(runner_class: 'Example::Source', function: 'produce')
relationships = client.find_subtasks(trigger_id: trigger.fetch(:function_id)) if trigger
client.find_delayed.each { |task| puts task.fetch(:id) }
```

The client uses configured, loaded Legion Data models and the standard settings helper with the Tasker namespace. Initialization registers defaults; subsequent reads use the live settings tree. `find_delayed` returns a lazy enumerable of Hash rows. It does not fabricate a model or hide a disconnected database. Specs use SQLite-backed models and in-process transport.

## Development

The Gemfile uses companion checkouts from `.ci-dependencies/<repo>` in coordinated PR CI, or the existing monorepo checkouts two directories above this extension when their gemspecs exist. Production dependencies retain their minimum released API versions.

## License

MIT
