require 'rails_helper'

describe Doorkeeper::OpenidConnect::Models::IdToken, type: :model do
  subject { described_class.new(access_token) }
  let(:access_token) { create :access_token, resource_owner_id: user.id }
  let(:user) { create :user }

  describe '#claims' do
    it 'returns all default claims' do
      expect(subject.claims[:iss]).to eq 'dummy'
      expect(subject.claims[:sub]).to eq user.id.to_s
      expect(subject.claims[:aud]).to eq access_token.application.uid
      expect(subject.claims[:exp]).to eq subject.claims[:iat] + 120
      expect(subject.claims[:iat]).to be_a Integer
    end
  end

  describe '#as_json' do
    it 'returns claims with blank values removed' do
      allow(subject).to receive(:issuer).and_return(nil)
      json = subject.as_json

      expect(json).to include :aud
      expect(json).not_to include :iss
    end
  end

  describe '#as_jws_token' do
    it 'returns claims encoded as JWT' do
      jwt = JSON::JWT.decode_compact_serialized subject.as_jws_token, Doorkeeper::OpenidConnect.signing_key
      expect(jwt.to_hash).to eq subject.as_json.stringify_keys
    end
  end
end
