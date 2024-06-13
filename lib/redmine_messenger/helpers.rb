# frozen_string_literal: true

module RedmineMessenger
  module Helpers
    def project_messenger_options(active)
      options_for_select({ l(:label_messenger_settings_default) => '0',
                           l(:label_messenger_settings_disabled) => '1',
                           l(:label_messenger_settings_enabled) => '2' }, active)
    end

    def issue_statuses(active)
      options_for_select(
        IssueStatus.sorted.map { |s| [s.name, s.id] },
        active
      )
    end

    def issue_trackers(active)
      options_for_select(
        Tracker.sorted.map { |s| [s.name, s.id] },
        active
      )
    end

    def project_setting_messenger_default_value(value)
      if Messenger.default_project_setting @project, value
        l :label_messenger_settings_enabled
      else
        l :label_messenger_settings_disabled
      end
    end
  end
end
