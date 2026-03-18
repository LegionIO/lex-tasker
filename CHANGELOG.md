# Changelog

## [0.3.0] - 2026-03-18

### Added
- Standalone `Tasker::Client` for programmatic subtask dispatch
- `expire_queued` implementation (was no-op stub)
- Shared `Helpers::TaskFinder` module (deduplicated from find_subtask + fetch_delayed)

### Fixed
- `extend` -> `include` for helper modules (instance methods were unreachable via AMQP dispatch)
- SQL injection risk: raw string interpolation replaced with Sequel DSL parameterized queries
- Cross-DB: backtick quoting, `legion.` prefix, `CONCAT()` replaced with Sequel joins
- `runners/log.rb`: `payload[:node_id]` -> `opts[:node_id]` (NameError fix)
- `runners/log.rb`: `Node.where(opts[:name])` -> `Node.where(name: opts[:name])`
- `runners/log.rb`: `runner.values.nil?` -> `runner.nil?` (NoMethodError fix)
- `runners/log.rb`: `TaskLog.all.delete` -> `TaskLog.dataset.delete` (was no-op)
- `runners/updater.rb`: added missing `return` on early exit
- `runners/task_manager.rb`: Sequel chain reassignment for status filter
- `runners/task_manager.rb`: MySQL `DATE_SUB` -> `Sequel.lit` with Ruby Time
- `runners/check_subtask.rb`: nil delay guard (`.to_i.zero?`)
- `runners/check_subtask.rb`: cache mutation via `relationship.dup`
- `runners/check_subtask.rb`: nil guard after `find_trigger`
- `runners/check_subtask.rb`: result/results fan-out handles both keys
- `fetch_delayed` queue TTL from 1ms to 1000ms
- Entry point `data_required?` is now class method only
- `Helpers::TaskFinder#subtask_query` extracted to reduce AbcSize in `find_subtasks`

### Removed
- `helpers/base.rb` (empty stub)
- `helpers/fetch_delayed.rb` (merged into TaskFinder)
- `helpers/find_subtask.rb` (merged into TaskFinder)
- Debug artifact `log.unknown task.class` in updater

## [0.2.3] - 2026-03-17

### Fixed
- Qualify `status` column as `tasks.status` in SQL JOIN query to resolve ambiguous column reference in `fetch_delayed` helper

## [0.2.2] - 2026-03-13

### Added
- Initial release
