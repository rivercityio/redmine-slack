module RedmineSlack
    module Patches
        module CustomFieldPatch
            def self.prepended(base)
                base.class_eval do
                    unloadable

                    safe_attributes 'notifiable'
                end
            end
        end
    end
end