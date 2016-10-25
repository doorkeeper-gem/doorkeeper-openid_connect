require 'rails_helper'

describe Doorkeeper::OpenidConnect do
  describe 'SIGNING_ALGORITHM' do
    it 'is hard-coded to RS256' do
      expect(subject::SIGNING_ALGORITHM).to eq 'RS256'
    end
  end

  describe '.signing_key' do
    it 'returns the private key as JWK instance' do
      expect(subject.signing_key).to be_instance_of JSON::JWK
      expect(subject.signing_key[:kid]).to eq 'IqYwZo2cE6hsyhs48cU8QHH4GanKIx0S4Dc99kgTIMA'
    end
  end
end
