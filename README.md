# lex-tasker

Task lifecycle manager for [LegionIO](https://github.com/LegionIO/LegionIO). Manages the full lifecycle of tasks within the framework: status tracking, subtask relationships, delayed task scheduling, task logging, and extension registration.

This is a core LEX required for task execution.

## Installation

```bash
gem install lex-tasker
```

## Functions

- **CheckSubtask** - After a task completes, find all relationship-linked subtasks and dispatch them (with delay, condition, or transformation routing as appropriate)
- **TaskManager** - DB housekeeping: purge old completed tasks, expire stale queued tasks
- **FetchDelayed** - Poll for tasks in `task.delayed` status; dispatch when their delay period has elapsed
- **Updater** - Update task records (status, function args, payload, results)
- **Log** - Task activity log CRUD (add, delete by task/node/id, delete all)

## How It Works

When a task completes, its runner calls `check_subtasks` via the task exchange. `lex-tasker` looks up any configured relationships for that function, creates child task records in the database, and publishes them to the appropriate queue - routing through `lex-conditioner`, `lex-transformer`, or directly to the target runner depending on relationship configuration.

Delayed tasks (those with `relationship_delay` or `task_delay`) are stored in the database with status `task.delayed` and dispatched by the `FetchDelayed` runner once their delay period has elapsed.

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `legion-data` (database persistence required)

## License

MIT
