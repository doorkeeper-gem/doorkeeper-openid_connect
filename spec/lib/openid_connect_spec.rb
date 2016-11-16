require 'rails_helper'

describe Doorkeeper::OpenidConnect do
  describe 'SIGNING_ALGORITHM' do
    it 'is an allowable Signing Algorithm' do
      let(:jwt_signing_algorithms) { %w[HS256 HS384 HS512 RS256 RS384 RS512 ES256 ES384 ES512] }
      expect(jwt_signing_algorithms).to include(subject::SIGNING_ALGORITHM)
    end
  end

  describe '.signing_key' do
    it 'returns the private key as JWK instance' do
      expect(subject.signing_key).to be_instance_of JSON::JWK
      expect(subject.signing_key[:kid]).to eq 'IqYwZo2cE6hsyhs48cU8QHH4GanKIx0S4Dc99kgTIMA'
    end
  end
end
