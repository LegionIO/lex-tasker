# lex-tasker: Task Lifecycle Manager for LegionIO

**Repository Level 3 Documentation**
- **Category**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that manages the full lifecycle of tasks within the framework. Tracks task status, manages subtask relationships, handles delayed task scheduling, and provides task logging. Central coordination point for task execution flow.

**License**: MIT

## Architecture

```
Legion::Extensions::Tasker
├── Actors/
│   ├── CheckSubtask       # Verifies subtask completion status
│   ├── TaskManager        # Core task lifecycle management
│   ├── FetchDelayed       # Retrieves delayed/scheduled tasks
│   ├── FetchDelayedPush   # Pushes delayed tasks for execution
│   ├── Updater            # Updates task status records
│   └── Log                # Task activity logging
├── Runners/
│   ├── CheckSubtask       # Subtask verification logic
│   ├── TaskManager        # Task management logic
│   ├── FetchDelayed       # Delayed task retrieval logic
│   └── Updater            # Status update logic
└── Transport/
    ├── Exchanges/Task     # Task exchange
    ├── Queues/
    │   ├── CheckSubtask   # Subtask check queue
    │   ├── TaskMananger   # Task management queue
    │   ├── FetchDelayed   # Delayed task queue
    │   ├── Subtask        # Subtask queue
    │   ├── TaskLog        # Task log queue
    │   ├── Updater        # Status update queue
    │   └── LexRegister    # Extension registration queue
    └── Messages/
        └── FetchDelayed   # Delayed task message format
```

## Key Files

| Path | Purpose |
|------|---------|
| `lib/legion/extensions/tasker.rb` | Entry point, extension registration |
| `lib/legion/extensions/tasker/actors/task_manager.rb` | Core task lifecycle actor |
| `lib/legion/extensions/tasker/actors/check_subtask.rb` | Subtask completion checking |
| `lib/legion/extensions/tasker/runners/` | All task management business logic |

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
