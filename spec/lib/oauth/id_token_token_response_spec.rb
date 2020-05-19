# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OAuth::IdTokenTokenResponse do
  subject { described_class.new(pre_auth, auth, id_token) }

  let(:token) { create :access_token }
  let(:application) do
    create(:application, scopes: 'public')
  end
  let(:pre_auth) do
    double(
      :pre_auth,
      client: application,
      redirect_uri: 'http://tst.com/cb',
      state: nil,
      scopes: Doorkeeper::OAuth::Scopes.from_string('public'),
      error: nil,
      authorizable?: true,
      nonce: '12345'
    )
  end
  let(:owner) { double(id: 1, to_i: 1) }
  let(:auth) do
    Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
      if c.respond_to?(:issue_token!)
        c.issue_token!
      else
        c.issue_token
      end
    end
  end
  let(:id_token) { Doorkeeper::OpenidConnect::IdToken.new(token, pre_auth) }

  describe '#redirect_uri' do
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
end
