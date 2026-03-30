# frozen_string_literal: true

require_relative 'helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      class Client
        include Helpers::TaskFinder

        def initialize(data_model: nil)
          @data_model = data_model
        end

        def models_class
          @data_model || Legion::Data::Model
        end

        def log
          @log ||= defined?(Legion::Logging) ? Legion::Logging : Logger.new($stdout) # rubocop:disable Legion/HelperMigration/LoggingGuard
        end

        def settings
          { options: {} }
        end
      end
    end
  end
end
