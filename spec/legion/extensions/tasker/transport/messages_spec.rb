# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/transport/messages/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Transport::Messages::FetchDelayed do
  it 'publishes the configured wake-up route and expiration in its transport envelope' do
    Legion::Settings.with_overlay(extensions: { tasker: { transport: { fetch_delayed_route: 'custom.delayed', fetch_delayed_expiration_ms: 9000 } } }) do
      message = described_class.new
      expect(message.publish_envelope_options(options: {})).to include(routing_key: 'custom.delayed', expiration: 9000)
    end
  end
end
