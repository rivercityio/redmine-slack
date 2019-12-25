class AddCustomFieldsNotifiable < ActiveRecord::Migration[5.2]
  def self.up
    add_column :custom_fields, :notifiable, :boolean, :default => true
  end

  def self.down
    remove_column :custom_fields, :notifiable
  end
end
