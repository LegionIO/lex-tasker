# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/actors/fetch_delayed_push'

RSpec.describe 'Tasker polling policy' do
  it 'applies runtime overlays to each polling interval without restarting the actor' do
    delayed = Legion::Extensions::Tasker::Actor::FetchDelayedPush.allocate
    Legion::Settings.with_overlay(extensions: { tasker: { delayed_poll_interval_seconds: 7 } }) do
      expect(delayed.time).to eq(7)
    end
  end
end
