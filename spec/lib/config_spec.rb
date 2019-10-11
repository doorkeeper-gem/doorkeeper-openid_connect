require 'rails_helper'

describe Doorkeeper::OpenidConnect, 'configuration' do
  subject { Doorkeeper::OpenidConnect.configuration }

  describe '#configure' do
    it 'fails if not set to :active_record' do
      # stub ORM setup to avoid Doorkeeper exceptions
      allow(Doorkeeper).to receive(:setup_orm_adapter)
      allow(Doorkeeper).to receive(:setup_orm_models)

      Doorkeeper.configure do
        orm :mongoid
      end

      expect do
        Doorkeeper::OpenidConnect.configure {}
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe 'jws_private_key' do
    it 'delegates to signing_key' do
      value = 'private_key'
      Doorkeeper::OpenidConnect.configure do
        jws_private_key value
      end
      expect(subject.signing_key).to eq(value)
    end
  end

  describe 'signing_key' do
    it 'sets the value that is accessible via signing_key' do
      value = 'private_key'
      Doorkeeper::OpenidConnect.configure do
        signing_key value
      end
      expect(subject.signing_key).to eq(value)
    end
  end

  describe 'issuer' do
    it 'sets the value that is accessible via issuer' do
      value = 'issuer'
      Doorkeeper::OpenidConnect.configure do
        issuer value
      end
      expect(subject.issuer).to eq(value)
    end
  end

  describe 'resource_owner_from_access_token' do
    it 'sets the block that is accessible via resource_owner_from_access_token' do
      block = proc {}
      Doorkeeper::OpenidConnect.configure do
        resource_owner_from_access_token(&block)
      end
      expect(subject.resource_owner_from_access_token).to eq(block)
    end

    it 'fails if unset' do
      Doorkeeper::OpenidConnect.configure {}

      expect do
        subject.resource_owner_from_access_token.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe 'auth_time_from_resource_owner' do
    it 'sets the block that is accessible via auth_time_from_resource_owner' do
      block = proc {}
      Doorkeeper::OpenidConnect.configure do
        auth_time_from_resource_owner(&block)
      end
      expect(subject.auth_time_from_resource_owner).to eq(block)
    end

    it 'fails if unset' do
      Doorkeeper::OpenidConnect.configure {}

      expect do
        subject.auth_time_from_resource_owner.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe 'reauthenticate_resource_owner' do
    it 'sets the block that is accessible via reauthenticate_resource_owner' do
      block = proc {}
      Doorkeeper::OpenidConnect.configure do
        reauthenticate_resource_owner(&block)
      end
      expect(subject.reauthenticate_resource_owner).to eq(block)
    end

    it 'fails if unset' do
      Doorkeeper::OpenidConnect.configure {}

      expect do
        subject.reauthenticate_resource_owner.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe 'subject' do
    it 'sets the block that is accessible via subject' do
      block = proc {}
      Doorkeeper::OpenidConnect.configure do
        subject(&block)
      end
      expect(subject.subject).to eq(block)
    end

    it 'fails if unset' do
      Doorkeeper::OpenidConnect.configure {}

      expect do
        subject.subject.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe 'expiration' do
    it 'sets the value that is accessible via expiration' do
      value = 'expiration'
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
      expect(subject.claims).to_not be_nil
    end
  end

  describe 'protocol' do
    it 'defaults to https in production' do
      expect(::Rails.env).to receive(:production?).and_return(true)

      expect(subject.protocol.call).to eq(:https)
    end

    it 'defaults to http in other environments' do
      expect(::Rails.env).to receive(:production?).and_return(false)

      expect(subject.protocol.call).to eq(:http)
    end

    it 'can be set to other protocols' do
      Doorkeeper::OpenidConnect.configure do
        protocol { :ftp }
      end

      expect(subject.protocol.call).to eq(:ftp)
    end
  end

  describe 'authorization_url_host' do
    it 'defaults to nil' do
      expect(subject.authorization_url_host).to be_nil
    end

    it 'can be set to other hosts' do
      Doorkeeper::OpenidConnect.configure do
        authorization_url_host "alternate-authorization-host"
      end

      expect(subject.authorization_url_host).to eq("alternate-authorization-host")
    end
  end
end
