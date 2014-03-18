class AddAnnouncementsEmailToUsers < ActiveRecord::Migration
  def change
    add_column :users, :announcements_email, :boolean, :default => true
  end
end
