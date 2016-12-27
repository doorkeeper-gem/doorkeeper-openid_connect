require 'rails_helper'

describe Doorkeeper::OpenidConnect::UserinfoController, type: :controller do
  let(:client) { create :application }
  let(:user)   { create :user, name: 'Joe' }
  let(:token)  { create :access_token, application: client, resource_owner_id: user.id }

  describe '#show' do
    context 'with a valid access token authorized for the openid scope' do
      let(:token) { create :access_token, application: client, resource_owner_id: user.id, scopes: 'openid' }

      it 'returns the basic user information as JSON' do
        get :show, access_token: token.token

        expect(response.status).to eq 200
        expect(response.body).to eq %Q{{"sub":"#{user.id}","variable_name":"openid-name","created_at":#{user.created_at.to_i}}}
      end
    end

    context 'with a valid access token authorized for the openid and profile scopes' do
      let(:token) { create :access_token, application: client, resource_owner_id: user.id, scopes: 'openid profile' }

      it 'returns the full user information as JSON' do
        get :show, access_token: token.token

        expect(response.status).to eq 200
        expect(response.body).to eq %Q{{"sub":"#{user.id}","name":"Joe","variable_name":"profile-name","created_at":#{user.created_at.to_i},"updated_at":#{user.updated_at.to_i}}}
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
