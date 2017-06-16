require 'rails_helper'

describe Doorkeeper::OpenidConnect::RpLogoutController, type: :controller do
  let(:client) { create :application }
  let(:user)   { create :user, name: 'Joe' }
  let(:token)  { create :access_token, application: client, resource_owner_id: user.id }

  describe '#show' do
    context 'with a valid post_logout_redirect_uri' do
      before(:each) do
        block = lambda { |*_| }
        Doorkeeper::OpenidConnect.configure do
          logout_resource_owner(&block)
        end
      end

      it 'redirects to the specified post_logout_redirect_uri' do
        get :show, post_logout_redirect_uri: 'https://test.venuenext.net'

        expect(response.status).to eq 302
        expect(response).to redirect_to('https://test.venuenext.net')
      end

      it 'redirects to the specified localhost post_logout_redirect_uri' do
        get :show, post_logout_redirect_uri: 'https://localhost:3000'

        expect(response.status).to eq 302
        expect(response).to redirect_to('https://localhost:3000')
      end

      it 'redirects to the specified post_logout_redirect_uri with the state' do
        get :show, post_logout_redirect_uri: 'https://test.venuenext.net', state: 'test123'

        expect(response.status).to eq 302
        expect(response).to redirect_to('https://test.venuenext.net?state=test123')
      end

      it 'replaces the state in an encoded post_logout_redirect_uri' do
        get :show, post_logout_redirect_uri: 'https://test.venuenext.net?state=bob', state: 'test321'

        expect(response.status).to eq 302
        expect(response).to redirect_to('https://test.venuenext.net?state=test321')
      end

      it 'merges the query parameters with the state in an encoded post_logout_redirect_uri' do
        get :show,
          post_logout_redirect_uri: 'https://test.venuenext.net/path/?state=bob&param2=8912',
          state: 'test999'

        expect(response.status).to eq 302
        expect(response).to redirect_to('https://test.venuenext.net/path/?state=test999&param2=8912')
      end

      it 'redirects to a custom scheme post_logout_redirect_uri' do
        get :show, post_logout_redirect_uri: 'vnapp://loggedout.venuenext.net'

        expect(response.status).to eq 302
        expect(response).to redirect_to('vnapp://loggedout.venuenext.net')
      end

      it 'redirects to a custom scheme post_logout_redirect_uri with the state param' do
        get :show, post_logout_redirect_uri: 'vnapp://loggedout.venuenext.net', state: 'app912'

        expect(response.status).to eq 302
        expect(response).to redirect_to('vnapp://loggedout.venuenext.net?state=app912')
      end
    end

    context 'with an invalid post_logout_redirect_uri' do
      before(:each) do
        block = lambda { |*_| }
        Doorkeeper::OpenidConnect.configure do
          logout_resource_owner(&block)
        end
      end

      it 'returns an error for non venuenext.net domains' do
        get :show, post_logout_redirect_uri: 'https://test.otherdomain.net'

        expect(response.status).to eq 400
      end

      it 'returns an error for invalid urls' do
        get :show, post_logout_redirect_uri: 'bob\test'

        expect(response.status).to eq 400
      end
    end
  end
end
