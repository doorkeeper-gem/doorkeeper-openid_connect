class AddCurrentSignInAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :current_sign_in_at, :datetime
  end
end
