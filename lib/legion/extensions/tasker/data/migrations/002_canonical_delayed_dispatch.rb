# frozen_string_literal: true

require 'legion/extensions/tasker/data/delayed_dispatch_migration'

Sequel.migration do
  up do
    Legion::Extensions::Tasker::Data::DelayedDispatchMigration.upgrade(db: self)
  end

  down do
    Legion::Extensions::Tasker::Data::DelayedDispatchMigration.rollback(db: self)
  end
end
