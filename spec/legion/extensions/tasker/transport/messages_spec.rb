# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/transport/messages/fetch_delayed'

RSpec.describe Legion::Extensions::Tasker::Transport::Messages::FetchDelayed do
  it 'honors configured wake-up expiration in its transport envelope' do
    Legion::Settings.with_overlay(extensions: { tasker: { transport: { fetch_delayed_expiration_ms: 9000 } } }) do
      message = described_class.new
      expect(message.publish_envelope_options(options: {})).to include(expiration: 9000)
    end
  end
end
