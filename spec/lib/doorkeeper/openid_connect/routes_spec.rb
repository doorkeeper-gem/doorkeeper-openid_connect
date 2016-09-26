require 'rails_helper'

describe Doorkeeper::OpenidConnect::Rails::Routes, type: :routing do
  it 'maps userinfo#show' do
    expect(get: 'oauth/userinfo').to route_to(
      controller: 'doorkeeper/openid_connect/userinfo',
      action: 'show'
    )
  end

  it 'maps discovery#show' do
    expect(get: '.well-known/openid-configuration').to route_to(
      controller: 'doorkeeper/openid_connect/discovery',
      action: 'show'
    )
  end
end
