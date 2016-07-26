require 'httpclient'

class SlackSender

    def common_msg(issue, journal)
        return "[#{escape issue.project}] #{escape journal.user.to_s} updated <#{object_url issue}|#{escape issue}>#{mentions journal.notes}"
    end

    def speak(msg, channel, attachment=nil, url=nil)
        url = Setting.plugin_redmine_slack[:slack_url] if not url
        username = Setting.plugin_redmine_slack[:username]
        icon = Setting.plugin_redmine_slack[:icon]

        params = {
            :text => msg,
            :link_names => 1,
        }

        params[:username] = username if username
        params[:channel] = channel if channel

        params[:attachments] = [attachment] if attachment

        if icon and not icon.empty?
            if icon.start_with? ':'
                params[:icon_emoji] = icon
            else
                params[:icon_url] = icon
            end
        end

        client = HTTPClient.new
        client.ssl_config.cert_store.set_default_paths
        client.ssl_config.ssl_version = "SSLv23"
        client.post url, {:payload => params.to_json}
    end

    def escape(msg)
        msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    def object_url(obj)
        Rails.application.routes.url_for(obj.event_url({:host => Setting.host_name, :protocol => Setting.protocol}))
    end

    def detail_to_field(detail)
        if detail.property == "cf"
            key = CustomField.find(detail.prop_key).name rescue nil
            title = key
        elsif detail.property == "attachment"
            key = "attachment"
            title = I18n.t :label_attachment
        else
            key = detail.prop_key.to_s.sub("_id", "")
            title = I18n.t "field_#{key}"
        end

        short = true
        value = escape detail.value.to_s

        case key
        when "title", "subject", "description"
            short = false
        when "tracker"
            tracker = Tracker.find(detail.value) rescue nil
            value = escape tracker.to_s
        when "project"
            project = Project.find(detail.value) rescue nil
            value = escape project.to_s
        when "status"
            status = IssueStatus.find(detail.value) rescue nil
            value = escape status.to_s
        when "priority"
            priority = IssuePriority.find(detail.value) rescue nil
            value = escape priority.to_s
        when "category"
            category = IssueCategory.find(detail.value) rescue nil
            value = escape category.to_s
        when "assigned_to"
            user = User.find(detail.value) rescue nil
            value = escape user.to_s
        when "fixed_version"
            version = Version.find(detail.value) rescue nil
            value = escape version.to_s
        when "attachment"
            attachment = Attachment.find(detail.prop_key) rescue nil
            value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
        when "parent"
            issue = Issue.find(detail.value) rescue nil
            value = "<#{object_url issue}|#{escape issue}>" if issue
        end

        value = "-" if value.empty?

        result = { :title => title, :value => value }
        result[:short] = true if short
        result
    end

    def mentions text
        names = extract_usernames text
        names.present? ? "\nTo: " + names.join(', ') : nil
    end

    def extract_usernames text = ''
        # slack usernames may only contain lowercase letters, numbers,
        # dashes and underscores and must start with a letter or number.
        text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
    end

end