require 'rails_helper'

describe Doorkeeper::OpenidConnect::DiscoveryController, type: :controller do
  describe '#provider' do
    it 'returns the provider configuration' do
      get :provider
      data = JSON.parse(response.body)

      expect(data.sort).to eq({
        'issuer' => 'dummy',
        'authorization_endpoint' => 'http://test.host/oauth/authorize',
        'token_endpoint' => 'http://test.host/oauth/token',
        'userinfo_endpoint' => 'http://test.host/oauth/userinfo',
        'jwks_uri' => 'http://test.host/oauth/discovery/keys',

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

        'claim_types_supported' => [
          'normal',
        ],

        'claims_supported' => [
          'iss',
          'sub',
          'aud',
          'exp',
          'iat',
          'name',
        ],
      }.sort)
    end

    it 'uses HTTPS URLs in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      get :provider
      data = JSON.parse(response.body)

      expect(data['authorization_endpoint']).to eq 'https://test.host/oauth/authorize'
    end
  end

  describe '#webfinger' do
    it 'requires the resource parameter' do
      expect do
        get :webfinger
      end.to raise_error ActionController::ParameterMissing
    end

    it 'returns the OpenID Connect relation' do
      get :webfinger, resource: 'user@example.com'
      data = JSON.parse(response.body)

      expect(data.sort).to eq({
        'subject' => 'user@example.com',
        'links' => [
          'rel' => 'http://openid.net/specs/connect/1.0/issuer',
          'href' => 'http://test.host/',
        ],
      }.sort)
    end
  end

  describe '#keys' do
    it 'returns the key parameters' do
      get :keys
      data = JSON.parse(response.body)

      expect(data.sort).to eq({
        'keys' => [
          {
            'kty' => 'RSA',
            'kid' => 'IqYwZo2cE6hsyhs48cU8QHH4GanKIx0S4Dc99kgTIMA',
            'e' => 'AQAB',
            'n' => 'sjdnSA6UWUQQHf6BLIkIEUhMRNBJC1NN_pFt1EJmEiI88GS0ceROO5B5Ooo9Y3QOWJ_n-u1uwTHBz0HCTN4wgArWd1TcqB5GQzQRP4eYnWyPfi4CfeqAHzQp-v4VwbcK0LW4FqtW5D0dtrFtI281FDxLhARzkhU2y7fuYhL8fVw5rUhE8uwvHRZ5CEZyxf7BSHxIvOZAAymhuzNLATt2DGkDInU1BmF75tEtBJAVLzWG_j4LPZh1EpSdfezqaXQlcy9PJi916UzTl0P7Yy-ulOdUsMlB6yo8qKTY1-AbZ5jzneHbGDU_O8QjYvii1WDmJ60t0jXicmOkGrOhruOptw',
            'use' => 'sig',
            'alg' => 'RS256',
          }
        ],
      }.sort)
    end
  end
end
