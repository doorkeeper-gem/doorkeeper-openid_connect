require 'rails_helper'

describe Doorkeeper::OAuth::CodeIdTokenTokenRequest do
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

  let(:owner) do
    double :owner, id: 7866
  end

  subject do
    Doorkeeper::OAuth::CodeIdTokenTokenRequest.new(pre_auth, owner)
  end

  it 'creates an access token' do
    expect do
      subject.authorize
    end.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it 'returns code id_token response' do
    expect(subject.authorize).to be_a(Doorkeeper::OAuth::CodeIdTokenResponse)
  end
end
