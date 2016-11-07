require 'rails_helper'

describe Doorkeeper::AuthorizationsController, type: :controller do
  let(:user) { create :user }

  describe '#resource_owner_authenticator' do
    it 'renders the authorization form if logged in' do
      get :new, current_user: user.id

      expect(response).to be_successful
    end

    it 'redirects to login form when not logged in' do
      get :new

      expect(response).to redirect_to '/login'
    end
  end

  describe '#validate_prompt_param!' do
    context 'with a prompt=none parameter' do
      it 'renders the authorization form if logged in' do
        get :new, current_user: user.id, prompt: 'none'

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

  describe '#validate_max_age_param!' do
    context 'with an invalid max_age parameter' do
      it 'renders the authorization form' do
        %w[ 0 -1 -23 foobar ].each do |max_age|
          get :new, current_user: user.id, max_age: max_age

          expect(response).to be_successful
        end
      end
    end

    context 'with a max_age=10 parameter' do
      it 'renders the authorization form if the users last login was within 10 seconds' do
        user.update! current_sign_in_at: 5.seconds.ago
        get :new, current_user: user.id, max_age: 10

        expect(response).to be_successful
      end

      it 'calls reauthenticate_resource_owner if the last login was longer than 10 seconds ago' do
        user.update! current_sign_in_at: 5.minutes.ago
        get :new, current_user: user.id, max_age: 10

        expect(response).to redirect_to '/reauthenticate'
      end

      it 'calls reauthenticate_resource_owner if the last login is unknown' do
        user.update! current_sign_in_at: nil
        get :new, current_user: user.id, max_age: 10

        expect(response).to redirect_to '/reauthenticate'
      end
    end
  end
end
