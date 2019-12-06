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

  describe '#delete' do
    it 'cascades to oauth_openid_requests' do
      pending('Rails 6 changes - https://github.com/doorkeeper-gem/doorkeeper-openid_connect/issues/91')

      access_grant = create(:access_grant, application: create(:application))
      create(:openid_request, access_grant: access_grant)

      expect { access_grant.delete }.to change(Doorkeeper::OpenidConnect::Request, :count).by(-1)
    end
  end
end
