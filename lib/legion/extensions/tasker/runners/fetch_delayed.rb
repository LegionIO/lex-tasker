module Legion::Extensions::Tasker::Runners
  class FetchDelayed
    def self.push
      require 'legion/data/models/tasks'

      tasks = Legion::Data::Model::Task.where(status: 'queued')
      tasks.each do |task|

      end
    end
  end
end