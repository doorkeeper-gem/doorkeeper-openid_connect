require 'rails_helper'

describe Doorkeeper::OpenidConnect::Nonce do
  describe 'validations' do
    it 'requires an access grant' do
      subject.access_grant_id = nil

      expect(subject).to_not be_valid
      expect(subject.errors).to include :access_grant_id
    end

    it 'requires a nonce' do
      subject.nonce = nil

      expect(subject).to_not be_valid
      expect(subject.errors).to include :nonce
    end
  end

  describe 'associations' do
    it 'belongs to an access_grant' do
      association = subject.class.reflect_on_association :access_grant

      expect(association.options).to eq({
        class_name: 'Doorkeeper::AccessGrant',
        inverse_of: :openid_connect_nonce,
      })
    end
  end

  describe '#use' do
    before do
      subject.nonce = '123456'
      allow(subject).to receive(:destroy!)
    end

    it 'destroys the record and returns the nonce' do
      expect(subject.use!).to eq '123456'
      expect(subject).to have_received(:destroy!)
    end
  end
end
