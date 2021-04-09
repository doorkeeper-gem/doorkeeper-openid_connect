# frozen_string_literal: true

require 'rails_helper'

describe 'doorkeeper modifications' do
  describe Doorkeeper::Request do
    it 'uses the correct strategy for "id_token" response types' do
      expect(described_class.authorization_strategy('id_token')).to eq(Doorkeeper::Request::IdToken)
    end

    it 'uses the correct strategy for "id_token token" response types' do
      expect(described_class.authorization_strategy('id_token token')).to eq(Doorkeeper::Request::IdTokenToken)
    end
  end
end
