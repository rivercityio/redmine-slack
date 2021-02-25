require 'redmine'
require 'redmine_slack/patches/user_preference_patch'
require 'redmine_slack/patches/issue_patch'
require 'redmine_slack/patches/custom_field_patch'

require_dependency 'redmine_slack/listener'

UserPreference.send(:prepend, RedmineSlack::Patches::UserPreferencePatch)
Issue.send(:prepend, RedmineSlack::Patches::IssuePatch)
CustomField.send(:prepend, RedmineSlack::Patches::CustomFieldPatch)

Rails.configuration.to_prepare do
  UserPreference.safe_attributes(
  	:slack_account,
  	:slack_notify_as_watcher,
  	:slack_assigned_notes, 
  	:slack_assigned
  )
end

Redmine::Plugin.register :redmine_slack do
	name 'Redmine Slack'
	author 'Samuel Cormier-Iijima'
	url 'https://github.com/sciyoshi/redmine-slack'
	author_url 'http://www.sciyoshi.com'
	description 'Slack chat integration'
	version '0.1.1'

	requires_redmine :version_or_higher => '0.8.0'

	settings \
		:default => {
			'callback_url' => 'http://slack.com/callback/',
			'channel' => nil,
			'icon' => 'https://raw.github.com/sciyoshi/redmine-slack/gh-pages/icon.png',
			'username' => 'redmine',
			'display_watchers' => 'no',
		},
		:partial => 'settings/slack_settings'
end
