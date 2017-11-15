require "redmine_slack/listener"

module RedmineSlack
    module Patches
        module IssuePatch

            def self.included(base)
                base.send(:include, InstanceMethods)

                base.class_eval do
                    unloadable
                    after_save :send_slack_notification
                end
            end

            module InstanceMethods
                def send_slack_notification
                    sender = SlackSender.new
                    issue = self
                    journal = self.current_journal
                    channel = SlackListener.channel_for_project issue.project
                    url = SlackListener.url_for_project issue.project

                    return unless url and Setting.plugin_redmine_slack[:post_updates] == '1'

                    if journal.notes
                        msg = "[#{sender.escape issue.project}] #{sender.escape journal.user.to_s} updated <#{sender.object_url issue}|#{sender.escape issue}>#{sender.mentions journal.notes}"
                    else
                        msg = "[#{sender.escape issue.project}] #{sender.escape journal.user.to_s} updated <#{sender.object_url issue}|#{sender.escape issue}>"
                    end
                    
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
                        elsif journal.notes != nil and journal.user != issue.assigned_to
                            sender.speak msg, "@" + cfAccount, attachment, url
                        end 
                    elsif cfAccount and cfSendAssigned
                        if cfNewAssign
                            sender.speak msg, "@" + cfAccount, attachment, url
                        end 
                    elsif cfAccount and cfSendAssignedNotes
                        if journal.notes != nil and journal.user != issue.assigned_to
                            sender.speak msg, "@" + cfAccount, attachment, url
                        end 
                    end

                    SlackListener.notify_watchers issue, sender, msg, attachment, url
                end
            end
        end
    end
end