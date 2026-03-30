# frozen_string_literal: true

require 'legion/extensions/tasker/version'

module Legion
  module Extensions
    module Tasker
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false

      def self.data_required?
        true
      end
    end
  end
end
