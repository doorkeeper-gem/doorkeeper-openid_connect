# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::OAuth::PreAuthorization do
  subject { Doorkeeper::OAuth::PreAuthorization.new server, attrs }

  let(:server) { Doorkeeper.configuration }
  let(:application) { create :application, scopes: 'openid public' }
  let(:attrs) {}

  describe '#initialize' do
    context 'with nonce parameter' do
      let(:attrs) { { nonce: '123456' } }

      it 'stores the nonce attribute' do
        expect(subject.nonce).to eq '123456'
      end
    end
  end

  describe '#authorizable?' do
    let(:client) { Doorkeeper::OAuth::Client.new(application) }

    context 'with response_type = id_token (implicit flow)' do
      let(:base_attrs) do
        {
          client_id: client.uid,
          response_type: 'id_token',
          redirect_uri: 'https://app.com/callback',
          scope: 'openid',
        }
      end

      before do
        allow(server).to receive(:grant_flows).and_return(['implicit_oidc'])
      end

      it 'is not authorizable without a nonce' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs)
        pre_auth.authorizable?

        expect(pre_auth).not_to be_authorizable
      end

      it 'is authorizable with a nonce' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(nonce: 'abc123'))
        pre_auth.authorizable?

        expect(pre_auth).to be_authorizable
      end

      it 'sets missing_param to :nonce when nonce is absent' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs)
        pre_auth.authorizable?

        expect(pre_auth.missing_param).to eq :nonce
      end
    end

    context 'with response_type = id_token token (implicit flow)' do
      let(:base_attrs) do
        {
          client_id: client.uid,
          response_type: 'id_token token',
          redirect_uri: 'https://app.com/callback',
          scope: 'openid',
        }
      end

      before do
        allow(server).to receive(:grant_flows).and_return(['implicit_oidc'])
      end

      it 'is not authorizable without a nonce' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs)
        pre_auth.authorizable?

        expect(pre_auth).not_to be_authorizable
      end

      it 'is authorizable with a nonce' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(nonce: 'abc123'))
        pre_auth.authorizable?

        expect(pre_auth).to be_authorizable
      end
    end

    context 'with response_type = code (authorization code flow)' do
      let(:base_attrs) do
        {
          client_id: client.uid,
          response_type: 'code',
          redirect_uri: 'https://app.com/callback',
          scope: 'openid',
        }
      end

      it 'is authorizable without a nonce' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs)
        pre_auth.authorizable?

        expect(pre_auth).to be_authorizable
      end

      it 'is authorizable with a nonce' do
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(nonce: 'abc123'))
        pre_auth.authorizable?

        expect(pre_auth).to be_authorizable
      end
    end
  end

  describe '#error_response' do
    context 'with response_type = code' do
      let(:attrs) { { response_type: 'code', redirect_uri: 'client.com/callback' } }

      it 'redirects to redirect_uri with query parameter' do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}\?/)
      end
    end

    context 'with response_type = token' do
      let(:attrs) { { response_type: 'token', redirect_uri: 'client.com/callback' } }

      it 'redirects to redirect_uri with fragment' do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}#/)
      end
    end

    context 'with response_type = id_token' do
      let(:attrs) { { response_type: 'id_token', redirect_uri: 'client.com/callback' } }

      it 'redirects to redirect_uri with fragment' do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}#/)
      end
    end

    context 'with response_type = id_token token' do
      let(:attrs) { { response_type: 'id_token token', redirect_uri: 'client.com/callback' } }

      it 'redirects to redirect_uri with fragment' do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}#/)
      end
    end
  end
end
