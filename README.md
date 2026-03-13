# lex-tasker

Task lifecycle manager for [LegionIO](https://github.com/LegionIO/LegionIO). Manages the full lifecycle of tasks within the framework: status tracking, subtask relationships, delayed task scheduling, task logging, and extension registration.

This is a core LEX required for task execution.

## Installation

```bash
gem install lex-tasker
```

## Functions

- **TaskManager** - Core task lifecycle management
- **CheckSubtask** - Verifies subtask completion status
- **FetchDelayed** - Retrieves delayed/scheduled tasks for execution
- **Updater** - Updates task status records
- **Log** - Task activity logging

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `legion-data` (database persistence)

## License

MIT
