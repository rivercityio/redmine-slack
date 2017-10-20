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

	def controller_issues_bulk_edit_before_save(context={})
		sender = SlackSender.new

		issue = context[:issue]
		journal = context[:params]['issue']
		channel = channel_for_project issue.project
		url = url_for_project issue.project
		currentUser = User.current

		return unless url and Setting.plugin_redmine_slack[:post_updates] == '1'

		msg = "[#{sender.escape issue.project}] #{currentUser} updated <#{sender.object_url issue}|#{sender.escape issue}>"

		attachment = {}
        attachment[:fields] = journal.map { |d| 
        	case d[0]
        	when "status_id"
            	{
        			:title => 'Status',
        			:value => sender.escape(issue.status.to_s),
        			:short => true
        		}
        	when "priority_id"
        		{
        			:title => 'Priority',
        			:value => sender.escape(issue.priority.to_s),
        			:short => true
        		}
        	when "assigned_to_id"
        		{
        			:title => 'Assignee',
        			:value => sender.escape(issue.assigned_to.to_s),
        			:short => true
        		}		
        	when "tracker_id"
        		{
        			:title => 'Tracker',
        			:value => sender.escape(issue.tracker.to_s),
        			:short => true
        		}		
        	when "done_ratio"
        		{
        			:title => '% Done',
        			:value => d[1],
        			:short => true
        		}			
        	end
        }
  
		if channel
			sender.speak msg, channel, attachment, url
		end

		# Sending notes updates to assignee
		cfAccount = issue.assigned_to.pref.slack_account rescue nil
		te = issue.assigned_to.mails
		cfSendAssigned = issue.assigned_to.pref.slack_assigned rescue nil
		cfNewAssign = false

		attachment[:fields].each do |field|
	    	if field[:title] == "Assignee"
	    		cfNewAssign = true
	    	end	
		end

		if cfAccount and cfSendAssigned
			if cfNewAssign
				sender.speak msg, "@" + cfAccount, attachment, url
			end	
		end

		notify_watchers issue, sender, msg, attachment, url

	end


	def controller_issues_edit_after_save(context={})

		sender = SlackSender.new

		issue = context[:issue]
		journal = context[:journal]

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless url and Setting.plugin_redmine_slack[:post_updates] == '1'

		msg = "[#{sender.escape issue.project}] #{sender.escape journal.user.to_s} updated <#{sender.object_url issue}|#{sender.escape issue}>#{sender.mentions journal.notes}"

		attachment = {}
        attachment[:text] = sender.escape journal.notes if journal.notes
        attachment[:fields] = journal.details.map { |d| sender.detail_to_field d }

		if channel
			sender.speak msg, channel, attachment, url
		end

		# Sending notes updates to assignee
		cfAccount = issue.assigned_to.pref.slack_account rescue nil
		cfSendAssignedNotes = issue.assigned_to.pref.slack_assigned_notes rescue nil
		cfSendAssigned = issue.assigned_to.pref.slack_assigned rescue nil
		cfNewAssign = false

		attachment[:fields].each do |field|
	    	if field[:title] == "Assignee"
	    		cfNewAssign = true
	    	end	
		end

		if cfAccount and cfSendAssigned and cfSendAssignedNotes
			if cfNewAssign
				sender.speak msg, "@" + cfAccount, attachment, url
			elsif not journal.notes.empty? and journal.user != issue.assigned_to
				sender.speak msg, "@" + cfAccount, attachment, url
			end	
		elsif cfAccount and cfSendAssigned
			if cfNewAssign
				sender.speak msg, "@" + cfAccount, attachment, url
			end	
		elsif cfAccount and cfSendAssignedNotes
			if not journal.notes.empty? and journal.user != issue.assigned_to
				sender.speak msg, "@" + cfAccount, attachment, url
			end	
		end

		notify_watchers issue, sender, msg, attachment, url
	end

private

	def notify_watchers(issue, sender, msg, attachment, url)
		issue.watcher_users.each do |user|
			if user.pref.slack_notify_as_watcher && user != issue.assigned_to
				cfAccount = user.pref.slack_account
				sender.speak msg, "@" + cfAccount, attachment, url
			end
		end
	end

	def url_for_project(proj)
        return nil if proj.blank?

        cf = ProjectCustomField.find_by_name("Slack URL")

        return [
            (proj.custom_value_for(cf).value rescue nil),
            (url_for_project proj.parent),
            Setting.plugin_redmine_slack[:slack_url],
        ].find{|v| v.present?}
    end

    def channel_for_project(proj)
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
