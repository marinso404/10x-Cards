# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.column :email_address, :citext, null: false
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :first_name

      t.timestamps
    end

    add_index :users, :email_address, unique: true
    add_index :users, %i[provider uid], unique: true, where: "provider IS NOT NULL", name: "index_users_on_provider_and_uid"
  end
end
