require 'rails_helper'

describe Doorkeeper::OpenidConnect::AccessGrant do
  subject { Doorkeeper::AccessGrant.new }

  it 'has one openid_connect_nonce' do
    association = subject.class.reflect_on_association :openid_connect_nonce

    expect(association.options).to eq({
      class_name: 'Doorkeeper::OpenidConnect::Nonce',
      inverse_of: :access_grant,
      dependent: :delete,
    })
  end
end
