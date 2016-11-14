require 'rails_helper'

describe Doorkeeper::OpenidConnect::UserInfo do
  subject { described_class.new user, token.scopes }
  let(:user) { create :user, name: 'Joe' }
  let(:token) { create :access_token, resource_owner_id: user.id, scopes: scopes }
  let(:scopes) { 'openid' }

  describe '#claims' do
    it 'returns all accessible claims' do
      expect(subject.claims).to eq({
        sub: user.id.to_s,
        created_at: user.created_at.to_i,
      })
    end

    context 'with a grant for the profile scopes' do
      let(:scopes) { 'openid profile' }

      it 'returns additional profile claims' do
        expect(subject.claims).to eq({
          sub: user.id.to_s,
          name: 'Joe',
          created_at: user.created_at.to_i,
          updated_at: user.updated_at.to_i,
        })
      end
    end
  end

  describe '#as_json' do
    it 'returns all accessible claims' do
      expect(subject.as_json).to eq subject.claims
    end
  end
end
