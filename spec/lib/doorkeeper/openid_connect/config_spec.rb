require 'rails_helper'

describe Doorkeeper::OpenidConnect, 'configuration' do
  subject { Doorkeeper::OpenidConnect.configuration }

  describe 'scopes' do
    it' adds the openid scope to the Doorkeeper configuration' do
      expect(Doorkeeper.configuration.scopes).to include 'openid'
    end
  end

  describe 'jws_private_key' do
    it 'sets the value that is accessible via jws_private_key' do
      value = ''
      Doorkeeper::OpenidConnect.configure do
        jws_private_key value
      end
      expect(subject.jws_private_key).to eq(value)
    end
  end

  describe 'jws_public_key' do
    it 'sets the value that is accessible via jws_public_key' do
      value = ''
      Doorkeeper::OpenidConnect.configure do
        jws_public_key value
      end
      expect(subject.jws_public_key).to eq(value)
    end
  end

  describe 'issuer' do
    it 'sets the value that is accessible via issuer' do
      value = ''
      Doorkeeper::OpenidConnect.configure do
        jws_public_key value
      end
      expect(subject.jws_public_key).to eq(value)
    end
  end

  describe 'resource_owner_from_access_token' do
    it 'sets the block that is accessible via resource_owner_from_access_token' do
      block = proc {}
      Doorkeeper::OpenidConnect.configure do
        resource_owner_from_access_token &block
      end
      expect(subject.resource_owner_from_access_token).to eq(block)
    end
  end

  describe 'subject' do
    it 'sets the block that is accessible via subject' do
      block = proc {}
      Doorkeeper::OpenidConnect.configure do
        subject &block
      end
      expect(subject.subject).to eq(block)
    end
  end

  describe 'expiration' do
    it 'sets the value that is accessible via expiration' do
      value = ''
      Doorkeeper::OpenidConnect.configure do
        expiration value
      end
      expect(subject.expiration).to eq(value)
    end
  end

  describe 'claims' do
    it 'sets the claims configuration that is accessible via claims' do
      Doorkeeper::OpenidConnect.configure do
        claims do
        end
      end
      expect(subject.claims).not_to be_nil
    end
  end
end
