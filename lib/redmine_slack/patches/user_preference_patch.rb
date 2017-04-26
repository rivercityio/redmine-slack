module RedmineSlack
  module Patches
    module UserPreferencePatch

      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
        end
      end

      module InstanceMethods
        def slack_account; self[:slack_account] end
        def slack_account=(value); self[:slack_account]=value; end

        def slack_notify_as_watcher; (self[:slack_notify_as_watcher] == true || self[:slack_notify_as_watcher] == '1'); end
        def slack_notify_as_watcher=(value); self[:slack_notify_as_watcher]=value; end

        def slack_assigned_notes; (self[:slack_assigned_notes] == true || self[:slack_assigned_notes] == '1'); end
        def slack_assigned_notes=(value); self[:slack_assigned_notes]=value; end

        def slack_assigned; (self[:slack_assigned] == true || self[:slack_assigned] == '1'); end
        def slack_assigned=(value); self[:slack_assigned]=value; end
      end
    end
  end
end
