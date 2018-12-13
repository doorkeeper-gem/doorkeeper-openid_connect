require 'rails_helper'

describe Doorkeeper::OAuth::CodeIdTokenRequest do
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
    Doorkeeper::OAuth::CodeIdTokenRequest.new(pre_auth, owner)
  end

  it 'creates an access token' do
    expect do
      subject.authorize
    end.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it 'returns code_id_token response' do
    expect(subject.authorize).to be_a(Doorkeeper::OAuth::CodeIdTokenResponse)
  end

  it 'does not create token when not authorizable' do
    allow(pre_auth).to receive(:authorizable?).and_return(false)
    expect { subject.authorize }.not_to change { Doorkeeper::AccessToken.count }
  end

  it 'returns a error response' do
    allow(pre_auth).to receive(:authorizable?).and_return(false)
    expect(subject.authorize).to be_a(Doorkeeper::OAuth::ErrorResponse)
  end


  context 'token reuse' do
    it 'creates a new token if there are no matching tokens' do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it 'creates a new token if scopes do not match' do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      FactoryGirl.create(:access_token, application_id: pre_auth.client.id,
                         resource_owner_id: owner.id, scopes: '')
      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it 'skips token creation if there is a matching one' do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      allow(application.scopes).to receive(:has_scopes?).and_return(true)
      allow(application.scopes).to receive(:all?).and_return(true)

      FactoryGirl.create(:access_token, application_id: pre_auth.client.id,
                         resource_owner_id: owner.id, scopes: 'openid')

      expect { subject.authorize }.not_to change { Doorkeeper::AccessToken.count }
    end
  end
end
