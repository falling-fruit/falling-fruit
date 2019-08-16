class PresenceConstraintChangesDescription < ActiveRecord::Migration
  def up 
    change_column :changes, :description, :text, null: false
  end
  def down 
    change_column :changes, :description, :text, null: true 
  end
end
