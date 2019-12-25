class SlackListener < Redmine::Hook::ViewListener
    render_on(:view_my_account_preferences, partial: 'my/redmine_slack_preferences')
    render_on(:view_custom_fields_form_upper_box, partial: 'custom_fields/notifiable_option')
end
