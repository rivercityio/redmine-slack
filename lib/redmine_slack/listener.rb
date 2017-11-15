require "redmine_slack/slack_sender"

class SlackListener < Redmine::Hook::ViewListener
	render_on(:view_my_account_preferences, partial: 'my/redmine_slack_preferences')

	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		sender = SlackSender.new

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless channel and url

		msg = "[#{sender.escape issue.project}] #{sender.escape issue.author} created <#{sender.object_url issue}|#{sender.escape issue}>#{sender.mentions issue.description}"

		attachment = {}
		attachment[:text] = sender.escape issue.description if issue.description
		attachment[:fields] = [{
			:title => I18n.t("field_status"),
			:value => sender.escape(issue.status.to_s),
			:short => true
		}, {
			:title => I18n.t("field_priority"),
			:value => sender.escape(issue.priority.to_s),
			:short => true
		}, {
			:title => I18n.t("field_assigned_to"),
			:value => sender.escape(issue.assigned_to.to_s),
			:short => true
		}]

		attachment[:fields] << {
			:title => I18n.t("field_watcher"),
			:value => sender.escape(issue.watcher_users.join(', ')),
			:short => true
		} if Setting.plugin_redmine_slack[:display_watchers] == 'yes'

		sender.speak msg, channel, attachment, url

		cfAccount = issue.assigned_to.pref.slack_account rescue nil
		cfSendAssigned = issue.assigned_to.pref.slack_assigned rescue nil

		if cfAccount and cfSendAssigned
			sender.speak msg, "@" + cfAccount, attachment, url
		end

		notify_watchers issue, sender, msg, attachment, url
	end

	def self.notify_watchers(issue, sender, msg, attachment, url)
		issue.watcher_users.each do |user|
			if user.pref.slack_notify_as_watcher && user != issue.assigned_to
				cfAccount = user.pref.slack_account
				sender.speak msg, "@" + cfAccount, attachment, url
			end
		end
	end

	def self.url_for_project(proj)
        return nil if proj.blank?

        cf = ProjectCustomField.find_by_name("Slack URL")

        return [
            (proj.custom_value_for(cf).value rescue nil),
            (url_for_project proj.parent),
            Setting.plugin_redmine_slack[:slack_url],
        ].find{|v| v.present?}
    end

    def self.channel_for_project(proj)
        return nil if proj.blank?

        cf = ProjectCustomField.find_by_name("Slack Channel")

        val = [
            (proj.custom_value_for(cf).value rescue nil),
            (channel_for_project proj.parent),
            Setting.plugin_redmine_slack[:channel],
        ].find{|v| v.present?}

        if val.to_s.starts_with? '#'
            val
        else
            nil
        end
    end

end
