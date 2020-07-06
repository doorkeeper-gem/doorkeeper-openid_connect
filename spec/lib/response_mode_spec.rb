# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::ResponseMode do
  describe '#mode' do
    it 'recognizes fragment response types' do
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('token').mode).to eq('fragment')
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('id_token').mode).to eq('fragment')
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('id_token token').mode).to eq('fragment')
    end

    it 'defaults to query' do
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('other').mode).to eq('query')
    end
  end

  describe '#fragment?' do
    it 'is truthy for the fragment mode' do
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('id_token')).to be_fragment
    end

    it 'is falsey for other modes' do
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('other')).not_to be_fragment
    end
  end

  describe '#query?' do
    it 'is truthy for the query mode' do
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('other')).to be_query
    end

    it 'is falsey for other modes' do
      expect(Doorkeeper::OpenidConnect::ResponseMode.new('id_token')).not_to be_query
    end
  end
end
