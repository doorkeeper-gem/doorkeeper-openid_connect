require 'rails_helper'

describe Doorkeeper::AuthorizationsController, type: :controller do
  let(:user) { create :user }
  let(:application) { create :application, scopes: default_scopes }
  let(:default_scopes) { 'openid profile' }
  let(:token_attributes) { { application_id: application.id, resource_owner_id: user.id, scopes: default_scopes } }

  def authorize!(params = {})
    get :new, {
      current_user: user.id,
      client_id: application.uid,
      scope: default_scopes,
    }.merge(params)
  end

  describe '#resource_owner_authenticator' do
    it 'renders the authorization form if logged in' do
      authorize!

      expect(response).to be_successful
    end

    it 'redirects to login form when not logged in' do
      authorize! current_user: nil

      expect(response).to redirect_to '/login'
    end
  end

  describe '#handle_prompt_param!' do
    context 'with a prompt=none parameter' do
      context 'and a matching token' do
        before do
          create :access_token, token_attributes
        end

        it 'renders the authorization form if logged in' do
          authorize! prompt: 'none'

          expect(response).to be_successful
        end

        it 'renders a login_required error when not logged in' do
          authorize! prompt: 'none', current_user: nil

          expect(response.status).to eq 401
          expect(JSON.parse(response.body)).to eq({
            'error' => 'login_required',
            'error_description' => 'The authorization server requires end-user authentication'
          })
        end

        it 'renders an invalid_request error if another prompt value is present' do
          authorize! prompt: 'none login'

          expect(response.status).to eq 401
          expect(JSON.parse(response.body)).to eq({
            'error' => 'invalid_request',
            'error_description' => 'The request is missing a required parameter, includes an unsupported parameter value, or is otherwise malformed.'
          })
        end
      end

      context 'and no matching token' do
        it 'renders a consent_required error when logged in' do
          authorize! prompt: 'none'

          expect(response.status).to eq 401
          expect(JSON.parse(response.body)).to eq({
            'error' => 'consent_required',
            'error_description' => 'The authorization server requires end-user consent'
          })
        end
      end
    end

    context 'with a prompt=login parameter' do
      it 'redirects to the sign in form if not logged in' do
        authorize! prompt: 'login', current_user: nil

        expect(response).to redirect_to('/login')
      end

      it 'reauthenticates the user if logged in' do
        authorize! prompt: 'login'

        expect(response).to redirect_to('/reauthenticate')
      end
    end

    context 'with a prompt=consent parameter' do
      it 'renders the authorization form if no matching tokens are found' do
        expect do
          authorize! prompt: 'consent'

          expect(response).to be_successful
        end.to_not change { Doorkeeper::AccessToken.count }
      end

      it 'deletes matching tokens and renders the authorization form' do
        create :access_token, token_attributes
        create :access_token, token_attributes
        create :access_token, token_attributes.merge(scopes: 'openid')
        create :access_token, token_attributes.merge(scopes: 'public')

        expect do
          authorize! prompt: 'consent'

          expect(response).to be_successful
        end.to change { Doorkeeper::AccessToken.count }.by(-2)
      end
    end

    context 'with a prompt=select_account parameter' do
      it 'renders an account_selection_required error' do
        authorize! prompt: 'select_account'

        expect(response.status).to eq 401
        expect(JSON.parse(response.body)).to eq({
          'error' => 'account_selection_required',
          'error_description' => 'The authorization server requires end-user account selection'
        })
      end
    end

    context 'with an unknown prompt parameter' do
        it 'renders an invalid_request error' do
          authorize! prompt: 'maybe'

          expect(response.status).to eq 401
          expect(JSON.parse(response.body)).to eq({
            'error' => 'invalid_request',
            'error_description' => 'The request is missing a required parameter, includes an unsupported parameter value, or is otherwise malformed.'
          })
        end
    end
  end

  describe '#handle_max_age_param!' do
    context 'with an invalid max_age parameter' do
      it 'renders the authorization form' do
        %w[ 0 -1 -23 foobar ].each do |max_age|
          authorize! max_age: max_age

          expect(response).to be_successful
        end
      end
    end

    context 'with a max_age=10 parameter' do
      it 'renders the authorization form if the users last login was within 10 seconds' do
        user.update! current_sign_in_at: 5.seconds.ago
        authorize! max_age: 10

        expect(response).to be_successful
      end

      it 'reauthenticates the user if the last login was longer than 10 seconds ago' do
        user.update! current_sign_in_at: 5.minutes.ago
        authorize! max_age: 10

        expect(response).to redirect_to '/reauthenticate'
      end

      it 'reauthenticates the user if the last login is unknown' do
        user.update! current_sign_in_at: nil
        authorize! max_age: 10

        expect(response).to redirect_to '/reauthenticate'
      end
    end
  end

  describe '#reauthenticate_resource_owner' do
    let(:performed) { true }

    before do
      allow(subject).to receive(:performed?) { performed }
      allow(subject.request).to receive(:path) { '/oauth/authorize' }
      allow(subject.request).to receive(:query_parameters) {
        { client_id: 'foo', prompt: 'login consent select_account' }.with_indifferent_access
      }
    end

    def reauthenticate!
      passed_args = nil

      Doorkeeper::OpenidConnect.configure do
        reauthenticate_resource_owner do |*args|
          passed_args = args
        end
      end

      subject.send :reauthenticate_resource_owner, user
      passed_args
    end

    it 'calls reauthenticate_resource_owner with the current user and the return path' do
      resource_owner, return_to = reauthenticate!

      expect(resource_owner).to eq user
      expect(return_to).to eq '/oauth/authorize?client_id=foo&prompt=consent+select_account'
    end

    it 'removes login from the prompt parameter and keeps other values' do
      _, return_to = reauthenticate!
      return_params = Rack::Utils.parse_query(URI.parse(return_to).query)

      expect(return_params['prompt']).to eq 'consent select_account'
    end

    context 'with a reauthenticator that does not generate a response' do
      let(:performed) { false }

      it 'raises a login_required error' do
        expect do
          reauthenticate!
        end.to raise_error(Doorkeeper::OpenidConnect::Errors::LoginRequired)
      end
    end
  end
end
