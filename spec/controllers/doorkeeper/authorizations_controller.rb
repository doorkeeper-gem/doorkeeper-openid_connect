require 'rails_helper'

describe Doorkeeper::AuthorizationsController, type: :controller do
  describe '#new' do
    context 'without a prompt parameter' do
      it 'renders the authorization form if logged in' do
        get :new, current_user: 'Joe'

        expect(response).to be_successful
      end

      it 'redirects to login form when not logged in' do
        get :new

        expect(response).to redirect_to '/login'
      end
    end

    context 'with a prompt=none parameter' do
      it 'renders the authorization form if logged in' do
        get :new, current_user: 'Joe', prompt: 'none'

        expect(response).to be_successful
      end

      it 'returns an error when not logged in' do
        get :new, prompt: 'none'

        expect(response.status).to eq 401
        expect(JSON.parse(response.body)).to eq({
          'error' => 'login_required',
          'error_description' => 'The authorization server requires end-user authentication'
        })
      end
    end
  end
end
