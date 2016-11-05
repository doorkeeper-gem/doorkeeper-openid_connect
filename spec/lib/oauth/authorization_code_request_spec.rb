require 'rails_helper'

describe Doorkeeper::OpenidConnect::OAuth::AuthorizationCodeRequest do
  subject {
    Doorkeeper::OAuth::AuthorizationCodeRequest.new(server, grant, client).tap do |request|
      request.instance_variable_set '@response', response
      request.access_token = token
    end
  }

  let(:server) { double }
  let(:client) { double }
  let(:grant) { create :access_grant, openid_connect_nonce: nonce }
  let(:nonce) { build :nonce, nonce: '123456' }
  let(:token) { create :access_token }
  let(:response) { Doorkeeper::OAuth::TokenResponse.new token }

  describe '#after_successful_response' do
    it 'adds the ID token to the response' do
      subject.send :after_successful_response

      expect(response.id_token).to be_a Doorkeeper::OpenidConnect::Models::IdToken
      expect(response.id_token.nonce).to eq '123456'
    end

    it 'skips the nonce if not present' do
      grant.openid_connect_nonce = nil
      subject.send :after_successful_response

      expect(response.id_token.nonce).to be_nil
    end
  end
end
