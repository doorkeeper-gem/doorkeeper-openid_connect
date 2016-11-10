require 'rails_helper'

describe Doorkeeper::OpenidConnect::AccessGrant do
  subject { Doorkeeper::AccessGrant.new }

  it 'has one openid_request' do
    association = subject.class.reflect_on_association :openid_request

    expect(association.options).to eq({
      class_name: 'Doorkeeper::OpenidConnect::Request',
      inverse_of: :access_grant,
      dependent: :delete,
    })
  end
end
