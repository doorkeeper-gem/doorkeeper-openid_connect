require 'rails_helper'

describe Doorkeeper::OpenidConnect::IdToken do
  subject { described_class.new(access_token, nonce) }
  let(:access_token) { create :access_token, resource_owner_id: user.id }
  let(:user) { create :user }
  let(:nonce) { '123456' }

  before do
    allow(Time).to receive(:now) { Time.at 60 }
  end

  describe '#nonce' do
    it 'returns the stored nonce' do
      expect(subject.nonce).to eq '123456'
    end
  end

  describe '#claims' do
    it 'returns all default claims' do
      expect(subject.claims).to eq({
        iss: 'dummy',
        sub: user.id.to_s,
        aud: access_token.application.uid,
        exp: 180,
        iat: 60,
        nonce: nonce,
        auth_time: 23,
      })
    end
  end

  describe '#as_json' do
    it 'returns claims with blank values removed' do
      allow(subject).to receive(:issuer).and_return(nil)
      json = subject.as_json

      expect(json).to include :aud
      expect(json).to_not include :iss
    end
  end

  describe '#as_jws_token' do
    it 'returns claims encoded as JWT' do
      jwt = JSON::JWT.decode_compact_serialized subject.as_jws_token, Doorkeeper::OpenidConnect.signing_key
      expect(jwt.to_hash).to eq subject.as_json.stringify_keys
    end
  end
end
