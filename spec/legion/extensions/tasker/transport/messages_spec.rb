# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Transport
    class Message
      def routing_key; end
      def expiration; end
      def publish; end
    end unless defined?(Legion::Transport::Message)
  end
end

$LOADED_FEATURES << 'legion/transport/message' unless $LOADED_FEATURES.include?('legion/transport/message')

# If the stub was defined without a superclass, remove it so the real file loads correctly
if defined?(Legion::Extensions::Tasker::Transport::Messages::FetchDelayed) &&
   Legion::Extensions::Tasker::Transport::Messages::FetchDelayed.superclass == Object
  Legion::Extensions::Tasker::Transport::Messages.send(:remove_const, :FetchDelayed)
end

require 'legion/extensions/tasker/transport/messages/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Transport::Messages::FetchDelayed do
  subject(:message) { described_class.allocate }

  it 'sets routing_key to fetch.delayed' do
    expect(message.routing_key).to eq('fetch.delayed')
  end

  it 'sets expiration to 5000 ms' do
    expect(message.expiration).to eq(5000)
  end

  it 'inherits from Legion::Transport::Message' do
    expect(described_class.superclass).to eq(Legion::Transport::Message)
  end
end
