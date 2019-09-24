require 'rails_helper'

describe Doorkeeper::OpenidConnect::OAuth::PreAuthorization do
  subject { Doorkeeper::OAuth::PreAuthorization.new server, { nonce: '123456' } }
  let(:server) { double }

  describe '#initialize' do
    it 'stores the nonce attribute' do
      expect(subject.nonce).to eq '123456'
    end
  end
end
