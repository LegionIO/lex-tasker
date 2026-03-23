# frozen_string_literal: true

require 'spec_helper'

require 'legion/extensions/tasker/transport/queues/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Transport::Queues::FetchDelayed do
  let(:queue) { described_class.allocate }

  it 'sets queue name to task.fetch_delayed' do
    expect(queue.queue_name).to eq('task.fetch_delayed')
  end

  it 'sets x-message-ttl to 1000 ms (not 1 ms)' do
    ttl = queue.queue_options.dig(:arguments, :'x-message-ttl')
    expect(ttl).to eq(1000)
  end

  it 'enables x-single-active-consumer' do
    sac = queue.queue_options.dig(:arguments, :'x-single-active-consumer')
    expect(sac).to eq(true)
  end
end
