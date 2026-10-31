# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:tasker_delayed_dispatch_backups) do
      Integer :task_id, primary_key: true
      String :original_values, text: true, null: false
      String :canonical_values, text: true, null: false
    end
  end

  down do
    drop_table(:tasker_delayed_dispatch_backups)
  end
end
