# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Extensions
    module Core; end unless defined?(Legion::Extensions::Core)
  end
end

require 'legion/extensions/tasker'

RSpec.describe Legion::Extensions::Tasker do
  it 'has a version number' do
    expect(Legion::Extensions::Tasker::VERSION).not_to be_nil
  end

  it 'declares data_required? as a class method returning true' do
    expect(described_class.data_required?).to eq(true)
  end

  it 'does not define an instance method data_required?' do
    obj = Object.new
    obj.extend(described_class)
    expect(obj).not_to respond_to(:data_required?)
  end
end
