class SlackListener < Redmine::Hook::ViewListener
    render_on(:view_my_account_preferences, partial: 'my/redmine_slack_preferences')
end
