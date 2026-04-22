# frozen_string_literal: true

class AddPostLogoutRedirectUrisToApplications < ActiveRecord::Migration[5.0]
  def change
    add_column :oauth_applications, :post_logout_redirect_uris, :text, null: true, default: nil
  end
end
