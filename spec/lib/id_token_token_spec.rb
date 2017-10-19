require 'rails_helper'

describe Doorkeeper::OpenidConnect::IdTokenToken do
  subject { described_class.new(access_token, nonce) }
  let(:access_token) { create :access_token, resource_owner_id: user.id }
  let(:user) { create :user }
  let(:nonce) { '123456' }

  before do
    allow(Time).to receive(:now) { Time.at 60 }
  end

  describe '#claims' do
    it 'returns all default claims' do
      # access token is from http://openid.net/specs/openid-connect-core-1_0.html
      # so we can test `at_hash` value
      access_token.update(token: 'jHkWEdUXMU1BwAsC4vtUsZwnNvTIxEl0z9K3vx5KF0Y')

      expect(subject.claims).to eq({
        iss: 'dummy',
        sub: user.id.to_s,
        aud: access_token.application.uid,
        exp: 180,
        iat: 60,
        nonce: nonce,
        auth_time: 23,
        at_hash: '77QmUPtjPfzWtF2AnpK9RQ'
      })
    end
  end
end
