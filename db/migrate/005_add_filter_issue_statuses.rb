# frozen_string_literal: true

class AddFilterIssueStatuses < ActiveRecord::Migration[6.1]
  def change
    add_column :messenger_settings, :filter_issue_statuses, :string, default: '', null: false
  end
end
