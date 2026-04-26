# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::OAuth::AuthorizationCodeRequest do
  subject do
    Doorkeeper::OAuth::AuthorizationCodeRequest.new(server, grant, client).tap do |request|
      request.instance_variable_set '@response', response
      request.instance_variable_set('@access_token', token)
    end
  end

  let(:server) { double }
  let(:client) { double }
  let(:grant) { create :access_grant, openid_request: openid_request }
  let(:openid_request) { create :openid_request, nonce: '123456' }
  let(:token) { create :access_token, scopes: 'openid' }
  let(:response) { Doorkeeper::OAuth::TokenResponse.new token }
  let(:openid_request_class) { Doorkeeper::OpenidConnect.configuration.open_id_request_model }

  describe '#after_successful_response' do
    it 'adds the ID token to the response when the openid scope is granted' do
      subject.send :after_successful_response

      expect(response.id_token).to be_a Doorkeeper::OpenidConnect::IdToken
      expect(response.id_token.nonce).to eq '123456'
    end

    it 'destroys the OpenID request record' do
      grant.save!

      expect do
        subject.send :after_successful_response
      end.to change { openid_request_class.count }.by(-1)
    end

    it 'skips the nonce if not present' do
      grant.openid_request.nonce = nil
      subject.send :after_successful_response

      expect(response.id_token.nonce).to be_nil
    end

    context 'when the access token does not include the openid scope' do
      let(:token) { create :access_token, scopes: 'public' }
      let(:grant) { create :access_grant, openid_request: nil }

      it 'does not build an ID token' do
        expect(Doorkeeper::OpenidConnect::IdToken).not_to receive(:new)

        subject.send :after_successful_response

        expect(response.id_token).to be_nil
      end
    end
  end
end
