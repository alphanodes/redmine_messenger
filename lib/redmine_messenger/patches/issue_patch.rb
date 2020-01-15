module RedmineMessenger
  module Patches
    module IssuePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create_commit :send_messenger_create
          after_update_commit :send_messenger_update
        end
      end

      module InstanceMethods
        def send_messenger_create
          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url
          return if is_private? && !Messenger.setting_for_project(project, :post_private_issues)

          set_language_if_valid Setting.default_language

          attachment = {}
          if description.present? && Messenger.setting_for_project(project, :new_include_description)
            attachment[:text] = Messenger.markup_format(description)
          end
          attachment[:fields] = [{ title: I18n.t(:field_status),
                                   value: Messenger.markup_format(status.to_s),
                                   short: true },
                                 { title: I18n.t(:field_priority),
                                   value: Messenger.markup_format(priority.to_s),
                                   short: true }]
          if assigned_to.present?
            attachment[:fields] << { title: I18n.t(:field_assigned_to),
                                     value: Messenger.markup_format(assigned_to.to_s),
                                     short: true }
          end

          if RedmineMessenger.setting?(:display_watchers) && watcher_users.count.positive?
            attachment[:fields] << {
              title: I18n.t(:field_watcher),
              value: Messenger.markup_format(watcher_users.join(', ')),
              short: true
            }
          end

          Messenger.speak(l(:label_messenger_issue_created,
                            project_url: "<#{Messenger.object_url project}|#{Messenger.markup_format(project)}>",
                            url: send_messenger_mention_url(project, description),
                            user: author),
                          channels, url, attachment: attachment, project: project)
        end

        def send_messenger_update
          return if current_journal.nil?

          should_be_sent = false
          if !RedmineMessenger.settings[:post_actions].empty?
            issue_update_active_actions = RedmineMessenger.settings[:post_actions]
  
            if issue_update_active_actions.include? "any"
              should_be_sent = true
            end
  
            current_journal.details.each do |detail|
              prop_string = detail.prop_key.to_s.sub('_id', '')
              if issue_update_active_actions.include? prop_string
                should_be_sent = true
              end
            end
          else
            should_be_sent = true
          end
  
          return if !should_be_sent

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url && Messenger.setting_for_project(project, :post_updates)
          return if is_private? && !Messenger.setting_for_project(project, :post_private_issues)
          return if current_journal.private_notes? && !Messenger.setting_for_project(project, :post_private_notes)

          set_language_if_valid Setting.default_language

          attachment = {}
          if Messenger.setting_for_project(project, :updated_include_description)
            attachment[:text] = Messenger.markup_format(description) if saved_change_to_description?

            if current_journal.notes.present?
              if attachment[:text].present?
                attachment[:text] << content_tag('p', l(:label_comment))
                attachment[:text] << Messenger.markup_format(current_journal.notes)
              else
                attachment[:text] = Messenger.markup_format(current_journal.notes)
              end
            end
          end

          fields = current_journal.details.map { |d| Messenger.detail_to_field d }
          if saved_change_to_status_id?
            fields << { title: I18n.t(:field_status),
                        value: Messenger.markup_format(status.to_s),
                        short: true }
          end

          if saved_change_to_priority_id?
            fields << { title: I18n.t(:field_priority),
                        value: Messenger.markup_format(priority.to_s),
                        short: true }
          end

          attachment[:fields] = fields if fields.any?

          Messenger.speak(l(:label_messenger_issue_updated,
                            project_url: "<#{Messenger.object_url project}|#{Messenger.markup_format(project)}>",
                            url: send_messenger_mention_url(project, description),
                            user: current_journal.user),
                          channels, url, attachment: attachment, project: project)
        end

        private

        def send_messenger_mention_url(project, text)
          mention_to = ''
          if Messenger.setting_for_project(project, :auto_mentions) ||
             Messenger.textfield_for_project(project, :default_mentions).present?
            mention_to = Messenger.mentions(project, text)
          end
          "<#{Messenger.object_url(self)}|#{Messenger.markup_format(self)}>#{mention_to}"
        end
      end
    end
  end
end
