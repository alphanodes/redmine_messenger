# Redmine Messenger plugin for Redmine

require 'redmine'
require 'redmine_messenger'

Redmine::Plugin.register :redmine_messenger do
  name 'Redmine Messenger'
  author 'AlphaNodes GmbH'
  url 'https://github.com/alphanodes/redmine_messenger'
  author_url 'https://alphanodes.com/'
  description 'Messenger integration for Slack, Rocketchat and Mattermost support'
  version '1.0.1'

  requires_redmine version_or_higher: '3.0.0'

  permission :manage_messenger, projects: :settings, messenger_settings: :save

  settings default: {
    messenger_url: '',
    messenger_icon: 'https://raw.githubusercontent.com/alphanodes/redmine_messenger/master/assets/images/icon.png',
    messenger_channel: 'redmine',
    messenger_username: 'robot',
    messenger_verify_ssl: '1',
    auto_mentions: '0',
    default_mentions: '',
    display_watchers: '0',
    post_updates: '1',
    new_include_description: '1',
    updated_include_assignee: '0',
    updated_include_description: '1',
    post_private_issues: '1',
    post_private_notes: '1',
    post_wiki: '0',
    post_wiki_updates: '0',
    post_db: '0',
    post_db_updates: '0',
    post_contact: '0',
    post_contact_updates: '0',
    post_password: '0',
    post_password_updates: '0'
  }, partial: 'settings/messenger_settings'
end
