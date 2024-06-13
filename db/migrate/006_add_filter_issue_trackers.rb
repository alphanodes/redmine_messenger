# frozen_string_literal: true

class AddFilterIssueTrackers < ActiveRecord::Migration[6.1]
  def change
    add_column :messenger_settings, :filter_issue_trackers, :string, default: '', null: false
  end
end
