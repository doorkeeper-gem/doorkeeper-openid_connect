require 'rails_helper'

describe Doorkeeper::OpenidConnect::OAuth::TokenResponse do
  subject { Doorkeeper::OAuth::TokenResponse.new token }
  let(:token) { create :access_token }
  let(:id_token) { Doorkeeper::OpenidConnect::IdToken.new token, '123456' }

  describe '#body' do
    before do
      subject.id_token = id_token
    end

    context 'with the openid scope present' do
      before do
        token.scopes = 'openid email'
      end

      it 'adds the ID token to the response' do
        expect(subject.body[:id_token]).to eq id_token.as_jws_token
      end
    end

    context 'with the openid scope not present' do
      before do
        token.scopes = 'email'
      end

      it 'does not add the ID token to the response' do
        expect(subject.body).to_not include :id_token
      end
    end
  end
end
