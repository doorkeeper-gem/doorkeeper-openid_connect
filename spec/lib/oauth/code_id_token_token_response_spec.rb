require 'rails_helper'

describe Doorkeeper::OAuth::CodeIdTokenTokenResponse do
  subject { Doorkeeper::OAuth::CodeIdTokenTokenResponse.new(pre_auth, auth, auth_token, id_token) }
  let(:token) { create :access_token }
  let(:application) do
    scopes = double(all: ['openid'])
    double(:application, id: 9990, scopes: scopes)
  end
  let(:pre_auth) do
    double(
        :pre_auth,
        client: application,
        redirect_uri: 'http://tst.com/cb',
        state: nil,
        scopes: Doorkeeper::OAuth::Scopes.from_string('openid'),
        error: nil,
        authorizable?: true,
        nonce: '12345'
    )
  end
  let(:auth) do
    Doorkeeper::OAuth::Authorization::Code.new(pre_auth, double(id: 1)).tap do |c|
      c.issue_token
    end
  end
  let(:auth_token) do
    Doorkeeper::OAuth::Authorization::Token.new(pre_auth, double(id: 1)).tap do |c|
      c.issue_token
    end
  end
  let(:id_token) { Doorkeeper::OpenidConnect::IdToken.new(token, pre_auth) }

  describe '#redirect_uri' do
    it 'includes code' do
      expect(subject.redirect_uri).to include('code')
    end

    it 'includes id_token' do
      expect(subject.redirect_uri).to include('id_token')
    end

    it 'includes access_token' do
      expect(subject.redirect_uri).to include('access_token')
    end

    it 'includes token_type' do
      expect(subject.redirect_uri).to include('token_type')
    end
  end

  describe '#form_response' do
    it 'includes code' do
      expect(subject.form_response).to include('code')
    end

    it 'includes id_token' do
      expect(subject.form_response).to include('id_token')
    end

    it 'includes access_token' do
      expect(subject.form_response).to include('access_token')
    end

    it 'includes token_type' do
      expect(subject.form_response).to include('token_type')
    end
  end
end
