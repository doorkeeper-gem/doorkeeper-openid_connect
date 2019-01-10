class CreateDoorkeeperOpenidConnectTables < ActiveRecord::Migration[5.2]
  def change
    create_table :oauth_openid_requests do |t|
      t.integer :access_grant_id, null: false
      t.string :nonce, null: false
    end

    add_foreign_key(
      :oauth_openid_requests,
      :oauth_access_grants,
      column: :access_grant_id
    )
  end
end
