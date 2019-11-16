require 'rails_helper'

describe Doorkeeper::AuthorizationsController, type: :controller do
  let(:user) { create :user }
  let(:application) { create :application, scopes: default_scopes }
  let(:default_scopes) { 'openid profile' }
  let(:token_attributes) { { application_id: application.id, resource_owner_id: user.id, scopes: default_scopes } }

  def authorize!(params = {})
    get :new, params: {
      response_type: 'code',
      current_user: user.id,
      client_id: application.uid,
      scope: default_scopes,
      redirect_uri: application.redirect_uri,
    }.merge(params)
  end

  def build_redirect_uri(params = {})
    Doorkeeper::OAuth::Authorization::URIBuilder.uri_with_query(application.redirect_uri, params)
  end

  def expect_authorization_form!
    expect(response).to be_successful
    expect(response).to render_template('doorkeeper/authorizations/new')
  end

  def expect_successful_callback!
    expect(response).to be_redirect
    expect(response.location).to match(/^#{Regexp.quote application.redirect_uri}\?code=[-\w]+$/)
  end

  describe '#authenticate_resource_owner!' do
    it 'redirects to login form when not logged in' do
      authorize! current_user: nil

      expect(response).to redirect_to '/login'
    end

    context 'with OIDC requests' do
      before do
        expect(controller).to receive(:handle_oidc_prompt_param!)
        expect(controller).to receive(:handle_oidc_max_age_param!)
      end

      it 'renders the authorization form if logged in' do
        authorize!

        expect_authorization_form!
      end
    end

    context 'with non-OIDC requests' do
      before do
        expect(controller).not_to receive(:handle_oidc_prompt_param!)
        expect(controller).not_to receive(:handle_oidc_max_age_param!)
      end

      it 'when action is not :new' do
        get :show, params: {
          response_type: 'code',
          current_user: user.id,
          client_id: application.uid,
          scope: default_scopes,
          redirect_uri: application.redirect_uri,
        }

        expect(response).to render_template('doorkeeper/authorizations/show')
      end

      context 'when pre_authorization is invalid' do
        it 'render error when client_id is missing' do
          authorize!(client_id: nil)

          expect(response).to be_successful
          expect(response).to render_template('doorkeeper/authorizations/error')
        end

        it 'render error when response_type is missing' do
          authorize!(response_type: nil)

          expect(response).to be_successful
          expect(response).to render_template('doorkeeper/authorizations/error')
        end
      end

      it 'when openid scope is not present' do
        authorize!(scope: 'profile')

        expect_authorization_form!
      end
    end
  end

  describe '#handle_oidc_prompt_param!' do
    it 'is ignored when the openid scope is not present' do
      authorize! scope: 'profile', prompt: 'invalid'

      expect_authorization_form!
    end

    context 'with a prompt=none parameter' do
      context 'and a matching token' do
        before do
          create :access_token, token_attributes
        end

        it 'redirects to the callback if logged in' do
          authorize! prompt: 'none'

          expect_successful_callback!
        end

        it 'returns an invalid_request error if another prompt value is present' do
          authorize! prompt: 'none login'

          error_params = {
            'error' => 'invalid_request',
            'error_description' => 'The request is missing a required parameter, includes an unsupported parameter value, or is otherwise malformed.',
          }

          expect(response.status).to redirect_to build_redirect_uri(error_params)
          expect(JSON.parse(response.body)).to eq(error_params)
        end

        context 'when not logged in' do
          let(:error_params) do
            {
              'error' => 'login_required',
              'error_description' => 'The authorization server requires end-user authentication',
              'state' => 'somestate',
            }
          end

          it 'returns a login_required error' do
            authorize! prompt: 'none', current_user: nil, state: 'somestate'

            expect(response).to redirect_to build_redirect_uri(error_params)
            expect(JSON.parse(response.body)).to eq(error_params)
          end
        end
      end

      context 'and no matching token' do
        it 'redirects to the callback if skip_authorization is set to true' do
          allow(controller).to receive(:skip_authorization?) { true }

          authorize! prompt: 'none'
          expect_successful_callback!
        end

        it 'returns a consent_required error when logged in' do
          authorize! prompt: 'none'

          error_params = {
            'error' => 'consent_required',
            'error_description' => 'The authorization server requires end-user consent',
          }

          expect(response).to redirect_to build_redirect_uri(error_params)
          expect(JSON.parse(response.body)).to eq(error_params)
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
      it 'renders the authorization form even if a matching token is present' do
        create :access_token, token_attributes
        authorize! prompt: 'consent'

        expect_authorization_form!
      end
    end

    context 'with a prompt=select_account parameter' do
      it 'returns an account_selection_required error' do
        authorize! prompt: 'select_account'

        error_params = {
          'error' => 'account_selection_required',
          'error_description' => 'The authorization server requires end-user account selection',
        }

        expect(response.status).to redirect_to build_redirect_uri(error_params)
        expect(JSON.parse(response.body)).to eq(error_params)
      end
    end

    context 'with an unknown prompt parameter' do
      it 'returns an invalid_request error' do
        authorize! prompt: 'maybe'

        error_params = {
          'error' => 'invalid_request',
          'error_description' => 'The request is missing a required parameter, includes an unsupported parameter value, or is otherwise malformed.',
        }

        expect(response).to redirect_to build_redirect_uri(error_params)
        expect(JSON.parse(response.body)).to eq(error_params)
      end

      it 'does not redirect to an invalid redirect_uri' do
        authorize! prompt: 'maybe', redirect_uri: 'https://evilapp.com'

        expect(response).not_to be_redirect
      end
    end
  end

  describe '#handle_oidc_max_age_param!' do
    context 'with an invalid max_age parameter' do
      it 'renders the authorization form' do
        %w[ 0 -1 -23 foobar ].each do |max_age|
          authorize! max_age: max_age

          expect_authorization_form!
        end
      end
    end

    context 'with a max_age=10 parameter' do
      it 'renders the authorization form if the users last login was within 10 seconds' do
        user.update! current_sign_in_at: 5.seconds.ago
        authorize! max_age: 10

        expect_authorization_form!
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

  describe '#reauthenticate_oidc_resource_owner' do
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

      subject.send :reauthenticate_oidc_resource_owner, user
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
