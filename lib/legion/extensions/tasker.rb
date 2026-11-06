# frozen_string_literal: true

require 'legion/extensions/tasker/version'
require 'legion/settings'
require 'legion/settings/helper'
require 'legion/transport/task/protocol'
require 'legion/logging/helper'

module Legion
  module Extensions
    module Tasker
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false

      def self.data_required?
        true
      end

      def self.transport_required?
        true
      end

      def self.default_settings
        {
          delayed_poll_interval_seconds: 1,
          delayed_batch_size:            100,
          default_delay_seconds:         0,
          empty_templates:               ['', '{}', '[]', 'null'],
          execution:                     { max_depth: 100, max_fanout: 1000 },
          housekeeping:                  {
            purge_age_seconds:  2_678_400,
            purge_limit:        100,
            queued_age_seconds: 3600,
            recovery_limit:     100,
            queued_statuses:    %i[queued conditioner_queued transformer_queued]
          },
          transport:                     {
            fetch_delayed_expiration_ms: 5000,
            fetch_delayed_ttl_ms:        1000
          }
        }
      end
    end
  end
end

Legion::Settings.merge_settings(:extensions, tasker: Legion::Extensions::Tasker.default_settings)
