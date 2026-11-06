# frozen_string_literal: true

require 'legion/extensions/tasker/helpers/task_finder'

module Legion
  module Extensions
    module Tasker
      class Client
        include Legion::Settings::Helper
        include Legion::Extensions::Tasker::Helpers::TaskFinder

        def segments
          [:tasker]
        end
      end
    end
  end
end
