# frozen_string_literal: true

class AddFilterStatuses < ActiveRecord::Migration[4.2]
  def change
    add_column :messenger_settings, :filter_status, :string, default: '', null: false
  end
end
