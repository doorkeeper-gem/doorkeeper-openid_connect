require 'rails_helper'

describe Doorkeeper::OpenidConnect::DiscoveryController, type: :controller do
  describe '#show' do
    it 'returns the provider configuration' do
      get :show
      configuration = JSON.parse(response.body)

      expect(configuration.sort).to eq({
        'issuer' => 'dummy',
        'authorization_endpoint' => 'https://test.host/oauth/authorize',
        'token_endpoint' => 'https://test.host/oauth/token',
        'userinfo_endpoint' => 'https://test.host/oauth/userinfo',

        'scopes_supported' => ['openid'],

        'response_types_supported' => ['code'],
        'response_modes_supported' => ['query', 'fragment'],

        'token_endpoint_auth_methods_supported' => [
          'client_secret_basic',
          'client_secret_post',
        ],

        'subject_types_supported' => [
          'public',
        ],

        'id_token_signing_alg_values_supported' => [
          'RS256',
        ],
      }.sort)
    end
  end
end
