# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/tasker/client'

RSpec.describe Legion::Extensions::Tasker::Helpers::TaskFinder do
  subject(:client) { Legion::Extensions::Tasker::Client.new }

  it 'normalizes real joined model instances into dispatchable hashes' do
    fixture = seed_relationship(engine: 'erb', transformation: '{}')
    trigger = client.find_trigger(runner_class: 'Example::Source', function: 'produce')
    relationships = client.find_subtasks(trigger_id: trigger[:function_id])

    expect(trigger).to eq(function_id: fixture[:trigger].id, runner_id: fixture[:trigger][:runner_id])
    expect(relationships.first).to be_a(Hash)
    expect(relationships.first).to include(relationship_id: fixture[:relationship].id, function_id: fixture[:action].id,
                                           runner_class: 'Example::Target', runner_routing_key: 'example.target.consume', engine: 'erb')
  end

  it 'does not dispatch a disabled relationship or stale cached definition' do
    fixture = seed_relationship
    expect(client.find_subtasks(trigger_id: fixture[:trigger].id).map { |row| row[:relationship_id] }).to eq([fixture[:relationship].id])
    fixture[:relationship].update(active: false)
    expect(client.find_subtasks(trigger_id: fixture[:trigger].id)).to eq([])
  end
end
