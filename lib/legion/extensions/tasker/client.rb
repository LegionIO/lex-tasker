# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      class Client
        include Legion::Extensions::Tasker::Helpers::TaskFinder

        def initialize
          Legion::Settings.merge_settings(:extensions, tasker: Legion::Extensions::Tasker.default_settings)
        end

        private

        def derive_settings_segments
          [:tasker]
        end
      end
    end
  end
end
