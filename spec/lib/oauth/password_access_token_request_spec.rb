# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::OAuth::PasswordAccessTokenRequest do
  subject { Doorkeeper::OAuth::PasswordAccessTokenRequest.new server, client, resource_owner, { nonce: '123456' } }

  let(:server) { double }
  let(:client) { double }
  let(:resource_owner) { create :user }
  let(:token) { create :access_token }
  let(:response) { Doorkeeper::OAuth::TokenResponse.new token }

  describe '#initialize' do
    it 'stores the nonce attribute' do
      expect(subject.nonce).to eq '123456'
    end
  end

  describe '#after_successful_response' do
    it 'adds the ID token to the response' do
      subject.instance_variable_set '@response', response
      subject.instance_variable_set '@access_token', token
      subject.send :after_successful_response

      expect(response.id_token).to be_a Doorkeeper::OpenidConnect::IdToken
      expect(response.id_token.nonce).to eq '123456'
    end
  end
end
