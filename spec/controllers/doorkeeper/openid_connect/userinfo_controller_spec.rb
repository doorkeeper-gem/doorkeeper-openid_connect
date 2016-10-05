require 'rails_helper'

describe Doorkeeper::OpenidConnect::UserinfoController, type: :controller do
  let(:client) { create :application }
  let(:user)   { User.create! name: 'Joe', password: 'sekret' }
  let(:token)  { create :access_token, application: client, resource_owner_id: user.id }

  describe '#show' do
    context 'with a valid access token authorized for the openid scope' do
      let(:token) { create :access_token, application: client, resource_owner_id: user.id, scopes: 'openid' }

      it 'returns the user information as JSON' do
        get :show, access_token: token.token

        expect(response.status).to eq 200
        expect(response.body).to eq %Q{{"sub":"#{user.id}","name":"Joe"}}
      end
    end

    context 'with a valid access token not authorized for the openid scope' do
      it 'returns an error' do
        get :show, access_token: token.token

        expect(response.status).to eq 403
      end
    end

    context 'without a valid access token' do
      it 'returns an error' do
        get :show, access_token: 'foobar'

        expect(response.status).to eq 401
      end
    end
  end
end
