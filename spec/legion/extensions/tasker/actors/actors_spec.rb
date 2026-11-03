# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/actors/fetch_delayed_push'
require 'legion/extensions/tasker/actors/outbox'

RSpec.describe 'Tasker polling policy' do
  it 'applies runtime overlays to each polling interval without restarting the actor' do
    delayed = Legion::Extensions::Tasker::Actor::FetchDelayedPush.allocate
    outbox = Legion::Extensions::Tasker::Actor::Outbox.allocate
    Legion::Settings.with_overlay(extensions: { tasker: { delayed_poll_interval_seconds: 7, outbox: { poll_interval_seconds: 3 } } }) do
      expect(delayed.time).to eq(7)
      expect(outbox.time).to eq(3)
    end
    expect(delayed.time).to eq(Legion::Extensions::Tasker.default_settings[:delayed_poll_interval_seconds])
  end
end
