# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::IdToken do
  subject { described_class.new(access_token, nonce) }

  let(:access_token) { create :access_token, resource_owner_id: user.id, scopes: 'openid' }
  let(:user) { create :user }
  let(:nonce) { '123456' }

  before do
    allow(Time).to receive(:now) { Time.zone.at 60 }
  end

  describe '#nonce' do
    it 'returns the stored nonce' do
      expect(subject.nonce).to eq '123456'
    end
  end

  describe '#claims' do
    it 'returns all default claims' do
      expect(subject.claims).to eq(
        iss: 'dummy',
        sub: user.id.to_s,
        aud: access_token.application.uid,
        exp: 180,
        iat: 60,
        nonce: nonce,
        auth_time: 23,
        both_responses: 'both',
        id_token_response: 'id_token',
      )
    end

    context 'when expires_in is specified for the token' do
      subject { described_class.new(access_token, nonce, expires_in) }

      let(:expires_in) { 10 }

      it 'returns expiration claim with the specified value' do
        expect(subject.claims[:exp]).to eq(subject.claims[:iat] + expires_in)
      end
    end
    
    context 'when the expiration is a block' do
      subject { described_class.new(access_token, nonce, expires_in) }

      let(:expires_in) { proc { |_, _| 10 } }

      it 'returns expiration claim with the specified value' do
        expect(subject.claims[:exp]).to eq(subject.claims[:iat] + expires_in.call(user, access_token.application))
      end
    end

    context 'when application is not set on the access token' do
      before do
        access_token.application = nil
      end

      it 'returns all default claims except audience' do
        expect(subject.claims).to eq(
          iss: 'dummy',
          sub: user.id.to_s,
          aud: nil,
          exp: 180,
          iat: 60,
          nonce: nonce,
          auth_time: 23,
          both_responses: 'both',
          id_token_response: 'id_token',
        )
      end
    end

    context 'when issuer block has arity 3' do
      before do
        Doorkeeper::OpenidConnect.configure do
          issuer do |resource_owner, application, _request|
            "#{resource_owner.id}-#{application&.uid}"
          end

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          auth_time_from_resource_owner do |resource_owner|
            resource_owner.current_sign_in_at
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it 'passes resource_owner and application to the issuer block' do
        claims = subject.claims
        expect(claims[:iss]).to eq "#{user.id}-#{access_token.application.uid}"
      end
    end

    context 'when auth_time_from_resource_owner is not configured' do
      before do
        Doorkeeper::OpenidConnect.configure do
          issuer 'dummy'

          resource_owner_from_access_token do |access_token|
            User.find_by(id: access_token.resource_owner_id)
          end

          subject do |resource_owner|
            resource_owner.id
          end
        end
      end

      it 'builds claims without raising and omits auth_time' do
        expect { subject.claims }.not_to raise_error
        expect(subject.claims[:auth_time]).to be_nil
        expect(subject.as_json).not_to include(:auth_time)
      end
    end
  end

  describe '#as_json' do
    it 'returns claims with nil values and empty strings removed' do
      allow(subject).to receive(:issuer).and_return(nil)
      allow(subject).to receive(:subject).and_return('')
      allow(subject).to receive(:audience).and_return(' ')

      json = subject.as_json

      expect(json).not_to include :iss
      expect(json).not_to include :sub
      expect(json).to include :aud
    end
  end

  describe '#as_jws_token' do
    shared_examples 'a jws token' do
      it 'returns claims encoded as JWT' do
        algorithms = [Doorkeeper::OpenidConnect.signing_algorithm.to_s]

        data, headers = ::JWT.decode subject.as_jws_token, Doorkeeper::OpenidConnect.signing_key.keypair, true, { algorithms: algorithms }

        expect(data.to_hash).to eq subject.as_json.stringify_keys
        expect(headers["kid"]).to eq Doorkeeper::OpenidConnect.signing_key.kid
        expect(headers["alg"]).to eq Doorkeeper::OpenidConnect.signing_algorithm.to_s
      end
    end

    it_behaves_like 'a jws token'

    context 'when signing_algorithm is EC' do
      before { configure_ec }

      it_behaves_like 'a jws token'
    end

    context 'when signing_algorithm is HMAC' do
      before { configure_hmac }

      it_behaves_like 'a jws token'
    end
  end
end
