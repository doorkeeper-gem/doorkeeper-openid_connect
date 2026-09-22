# frozen_string_literal: true

class AddBackchannelLogoutUriToApplications < ActiveRecord::Migration[6.0]
  def change
    add_column :oauth_applications, :backchannel_logout_uri, :string
  end
end
