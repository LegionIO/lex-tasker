# lex-tasker: Task Lifecycle Manager for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that manages the full lifecycle of tasks within the framework. Tracks task status, manages subtask relationships, handles delayed task scheduling, extension registration, and provides task logging. Central coordination point for task execution flow. Requires `legion-data` (`data_required? true`).

**GitHub**: https://github.com/LegionIO/lex-tasker
**License**: MIT
**Version**: 0.2.3

## Architecture

```
Legion::Extensions::Tasker
├── Actors/
│   ├── CheckSubtask       # Subscription: checks subtask completion status
│   ├── TaskManager        # Subscription: core task lifecycle management
│   ├── FetchDelayed       # Subscription: retrieves delayed tasks for execution
│   ├── FetchDelayedPush   # Periodic actor: triggers FetchDelayed polls
│   ├── Updater            # Subscription: updates task status/payload records
│   └── Log                # Subscription: task activity logging
├── Runners/
│   ├── CheckSubtask       # check_subtasks: find and dispatch relationship subtasks
│   ├── TaskManager        # purge_old, expire_queued: task DB maintenance
│   ├── FetchDelayed       # fetch, push: poll and dispatch delayed tasks
│   ├── Updater            # update_status: update task columns in DB
│   └── Log                # add_log, delete_log, delete_task_logs, delete_node_logs, delete_all
├── Helpers/
│   ├── Base               # Shared helper utilities
│   ├── FetchDelayed       # Delayed task query helpers
│   └── FindSubtask        # Subtask relationship lookup helpers
└── Transport/
    ├── Exchanges/Task     # Task exchange
    ├── Queues/
    │   ├── CheckSubtask   # Subtask check queue
    │   ├── TaskMananger   # Task management queue (note: typo in filename)
    │   ├── FetchDelayed   # Delayed task queue
    │   ├── Subtask        # Subtask queue
    │   ├── TaskLog        # Task log queue
    │   ├── Updater        # Status update queue
    │   └── LexRegister    # Extension registration queue
    └── Messages/
        └── FetchDelayed   # Delayed task poll message
```

## Key Files

| Path | Purpose |
|------|---------|
| `lib/legion/extensions/tasker.rb` | Entry point (`data_required? true`) |
| `lib/legion/extensions/tasker/runners/check_subtask.rb` | Core subtask dispatch: find relationships, build task hash, insert DB record, publish |
| `lib/legion/extensions/tasker/runners/task_manager.rb` | `purge_old` (delete old completed tasks), `expire_queued` (queries stale tasks - incomplete, does not delete) |
| `lib/legion/extensions/tasker/runners/fetch_delayed.rb` | Poll DB for delayed tasks, dispatch when delay elapsed |
| `lib/legion/extensions/tasker/runners/updater.rb` | `update_status`: update task columns (status, function_args, payload, results) |
| `lib/legion/extensions/tasker/runners/log.rb` | Task log CRUD against `TaskLog` model |

## CheckSubtask Flow

1. Receives completed task result with `runner_class` and `function`
2. Looks up trigger function by namespace + name
3. Queries relationships where `trigger_function_id` matches
4. For each matching relationship, builds subtask hash with status (`task.delayed` or `conditioner.queued`)
5. Inserts task record in DB, then publishes to subtask queue (unless delayed)

## Delayed Task Flow

`FetchDelayedPush` (Every actor, every 1 second) publishes a trigger via `push`. `FetchDelayed` (Subscription actor, `fetch` function) polls DB for tasks in `task.delayed` status, checks if `relationship_delay` or `task_delay` has elapsed, then dispatches them. Routing key is chosen based on whether conditions or transformations are present.

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
