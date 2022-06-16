# frozen_string_literal: true

class CreateMessengerSettings < ActiveRecord::Migration[4.2]
  def change
    create_table :messenger_settings do |t|
      t.references :project, null: false, index: true
      t.string :messenger_url
      t.string :messenger_icon
      t.string :messenger_channel
      t.string :messenger_username
      t.integer :messenger_verify_ssl, default: 0, null: false
      t.integer :auto_mentions, default: 0, null: false
      t.integer :display_watchers, default: 0, null: false
      t.integer :post_updates, default: 0, null: false
      t.integer :new_include_description, default: 0, null: false
      t.integer :updated_include_description, default: 0, null: false
      t.integer :post_private_issues, default: 0, null: false
      t.integer :post_private_notes, default: 0, null: false
      t.integer :post_wiki, default: 0, null: false
      t.integer :post_wiki_updates, default: 0, null: false
      t.integer :post_db, default: 0, null: false
      t.integer :post_db_updates, default: 0, null: false
      t.integer :post_contact, default: 0, null: false
      t.integer :post_contact_updates, default: 0, null: false
      t.integer :post_password, default: 0, null: false
      t.integer :post_password_updates, default: 0, null: false
    end
  end
end
