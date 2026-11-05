# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/transport/queues/fetch_delayed'

RSpec.describe 'Tasker queue policy' do
  it 'allows operators to tune delayed wakeup retention independently of task retention' do
    Legion::Settings.with_overlay(extensions: { tasker: { transport: { fetch_delayed_queue: 'custom.delay', fetch_delayed_ttl_ms: 2000 } } }) do
      queue = Legion::Extensions::Tasker::Transport::Queues::FetchDelayed.allocate
      expect(queue.queue_name).to eq('custom.delay')
      expect(queue.queue_options[:arguments]).to include('x-message-ttl': 2000)
    end
  end
end
